import 'dart:io';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'playback/media_handler.dart';
import 'log.dart';
import 'ui/bot_setup.dart';
import 'ui/cover_colors.dart';
import 'ui/cover_gradient.dart';
import 'ui/glass/glass_surface.dart';
import 'ui/home.dart';
import 'ui/keyboard.dart';
import 'ui/look.dart';
import 'ui/theme.dart';
import 'ui/ui_prefs.dart';
import 'ui/widgets.dart';

/// Release builds can't name the widget behind "RenderBox was not laid out", so this finds
/// every box with no size yet and lists the widgets above it, nearest first.
String _unlaidWidgets() {
  final found = <String>[];
  void visit(Element e) {
    if (found.length >= 5) return;
    final r = e.renderObject;
    if (r is RenderBox && !r.hasSize) {
      final chain = <String>[];
      e.visitAncestorElements((a) {
        chain.add('${a.widget.runtimeType}');
        return chain.length < 14;
      });
      found.add('${e.widget.runtimeType} in ${chain.join(' < ')}');
    }
    e.visitChildElements(visit);
  }

  try {
    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  } catch (e) {
    return 'search failed ($e)';
  }
  return found.isEmpty ? 'none found' : found.join(' ;; ');
}

/// Shows failure toasts on any screen.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Covers are small, but the default cache (1 GB cap) keeps far more than is on screen.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 64 << 20
    ..maximumSize = 300;
  final printLine = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) logEvent('app', message);
    printLine(message, wrapWidth: wrapWidth);
  };
  accountLoggedIn = () => app.userSession.loggedIn.value;
  final reportError = FlutterError.onError;
  FlutterError.onError = (details) {
    // The top of the stack says where it came from, which the message alone doesn't.
    final where = (details.stack?.toString().split('\n') ?? const <String>[]).take(40).join(' | ');
    logEvent('app', '${details.exceptionAsString()} @ $where', level: LogLevel.error);
    logEvent('app', details.toString().replaceAll('\n', ' | '));
    if (details.exceptionAsString().contains('was not laid out')) logEvent('app', 'Not laid out: ${_unlaidWidgets()}');
    appLog.recordCrash('${details.exceptionAsString()}\n$where');
    reportError?.call(details);
  };
  final support = await getApplicationSupportDirectory();
  await appLog.attach(Directory(p.join(support.path, 'logs')));
  if (Platform.isAndroid) {
    await AudioService.init(
      builder: () => TeleplayerHandler(app.player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.max.paperplay.audio',
        // A white one-colour icon: Android shows the launcher icon as a blank circle here.
        androidNotificationIcon: 'drawable/ic_stat_teleplayer',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: true,
      ),
    );
  } else if (Platform.isWindows || Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  }
  // Before any player exists, so Windows can hook the first one.
  app.sound.start();
  app.player.outputName = () => app.sound.current.value?.name;
  app.sound.current.addListener(app.player.onOutputChanged);
  await GlassShaders.load();
  await app.ui.load();
  await loadSortPrefs();
  await app.td.loadKeys();
  if (app.td.hasKeys.value) await app.start();
  app.mediaSession.start();
  await app.background.start();
  installPlayerKeys(() => app.player.out, onSearch: () => app.searchRequests.value++);
  failureToast.stream.listen((m) => appMessenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 6))));
  runApp(const TeleplayerApp());
}

/// Lets a mouse drag the horizontal shelves, which have no wheel direction.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };
}

class TeleplayerApp extends StatelessWidget {
  const TeleplayerApp({super.key});

  /// The colours for the chosen accent. A cover's colours apply only once ready.
  ColorScheme _scheme(ColorScheme? system, Brightness brightness) {
    final accent = app.ui.accent.value;
    if (accent == accentDynamic && system != null) return system;
    if (accent == accentCover) {
      final cover = coverSchemeNow(app.player.current.value?.coverPath, brightness);
      if (cover != null) return cover;
    }
    final seed = accentOptions.where((a) => a.id == accent).firstOrNull?.seed ?? fallbackSeed;
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  }

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    // Monet: colours from the wallpaper on Android 12+, the Windows accent on a PC.
    builder: (light, dark) => ListenableBuilder(
      listenable: Listenable.merge([
        app.ui.themeMode,
        app.ui.amoled,
        app.ui.accent,
        app.ui.coverGradient,
        app.coverAccentReady,
        app.ui.lookChanges,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'Paper Play',
        scaffoldMessengerKey: appMessenger,
        navigatorKey: appNavigator,
        debugShowCheckedModeBanner: false,
        scrollBehavior: const _AppScrollBehavior(),
        themeMode: app.ui.themeMode.value,
        // A cover accent changes with every song: easing the whole app through each
        // change rebuilt every widget for 200 ms, which was the stutter when switching.
        themeAnimationDuration: app.ui.accent.value == accentCover ? Duration.zero : kThemeAnimationDuration,
        builder: (context, child) => CoverGradient(child: child ?? const SizedBox.shrink()),
        theme: buildTheme(
          _scheme(light, Brightness.light),
          seeThrough: app.ui.coverGradient.value,
          looks: {for (final g in LookGroup.values) g: app.ui.look(g)},
        ),
        darkTheme: buildTheme(
          _scheme(dark, Brightness.dark),
          amoled: app.ui.amoled.value,
          seeThrough: app.ui.coverGradient.value,
          looks: {for (final g in LookGroup.values) g: app.ui.look(g)},
        ),
        home: ValueListenableBuilder(
          valueListenable: app.libraryReady,
          builder: (context, ready, _) => ready ? const HomeScreen() : const BotSetupScreen(),
        ),
      ),
    ),
  );
}
