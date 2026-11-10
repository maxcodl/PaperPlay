import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../library/db.dart';
import 'glass/glass_style.dart';
import 'glass/nav_style.dart';
import 'look.dart';

/// An accent colour the owner can pick.
class AccentOption {
  const AccentOption(this.id, this.name, [this.seed]);
  final String id, name;

  /// Null for the two that change on their own: the system's and the cover's.
  final Color? seed;
}

const accentDynamic = 'dynamic', accentCover = 'cover';

const accentOptions = [
  AccentOption(accentDynamic, 'System'),
  AccentOption(accentCover, 'Current cover'),
  AccentOption('violet', 'Violet', Color(0xFF7C5CFF)),
  AccentOption('ocean', 'Ocean', Color(0xFF2F80ED)),
  AccentOption('mint', 'Mint', Color(0xFF2FBF8F)),
  AccentOption('amber', 'Amber', Color(0xFFE8A33D)),
  AccentOption('coral', 'Coral', Color(0xFFF2643D)),
  AccentOption('rose', 'Rose', Color(0xFFE8487F)),
  AccentOption('slate', 'Slate', Color(0xFF7B8CA8)),
];

/// Appearance choices. They're saved on this device only: device sync doesn't
/// carry settings, and a restored backup leaves them alone (see [AppDb.devicePrefs]).
class UiPrefs {
  UiPrefs(this._db);

  final AppDb _db;

  static const _floatingKey = 'floating_nav', _navKey = 'nav_style', _glassKey = 'glass_style';

  final floatingNav = ValueNotifier(true);
  final navStyle = ValueNotifier(const NavStyle());
  final glass = ValueNotifier(const GlassStyle());

  /// Material 3 or glass, for each part of the interface. The bar was glass before this was
  /// a choice, so it starts that way.
  final looks = {for (final g in LookGroup.values) g: ValueNotifier(g == LookGroup.nav ? Look.glass : Look.material)};
  Listenable get lookChanges => Listenable.merge(looks.values.toList());

  Look look(LookGroup g) => looks[g]!.value;

  Future<void> setLook(LookGroup g, Look l) {
    looks[g]!.value = l;
    return _db.setPref('look_${g.name}', l.name);
  }

  Future<void> setAllLooks(Look l) async {
    for (final g in LookGroup.values) {
      await setLook(g, l);
    }
  }

  /// Who the profile page says it is, and their photo's file. This device only.
  final profileName = ValueNotifier('Listener');
  final profilePhoto = ValueNotifier<String?>(null);

  /// When the name and photo last changed, so the newest change wins between devices.
  var _nameAt = 0, _photoAt = 0;

  /// Told when the person changes their name or photo here, so other devices can follow.
  void Function()? onProfileChanged;
  final themeMode = ValueNotifier(ThemeMode.system);

  /// Pure black dark surfaces. It has no effect in light mode.
  final amoled = ValueNotifier(true);
  final accent = ValueNotifier(accentDynamic);

  /// The PC's side panel showing the current song.
  final nowPlayingPanel = ValueNotifier(true);

  /// A background that fades from the colours of the song's cover into the plain one.
  final coverGradient = ValueNotifier(false);

  Future<void> load() async {
    floatingNav.value = await _db.pref(_floatingKey) != 'false';
    navStyle.value = _decode(await _db.pref(_navKey), NavStyle.fromJson, const NavStyle());
    glass.value = _decode(await _db.pref(_glassKey), GlassStyle.fromJson, const GlassStyle());
    for (final g in LookGroup.values) {
      final saved = await _db.pref('look_${g.name}');
      looks[g]!.value = Look.values.where((l) => l.name == saved).firstOrNull ?? looks[g]!.value;
    }
    profileName.value = await _db.pref('profile_name') ?? 'Listener';
    final photo = await _db.pref('profile_photo');
    profilePhoto.value = photo == null || photo.isEmpty ? null : photo;
    _nameAt = int.tryParse(await _db.pref('profile_name_at') ?? '') ?? 0;
    _photoAt = int.tryParse(await _db.pref('profile_photo_at') ?? '') ?? 0;
    final mode = await _db.pref('theme_mode');
    themeMode.value = ThemeMode.values.where((m) => m.name == mode).firstOrNull ?? ThemeMode.system;
    amoled.value = await _db.pref('theme_amoled') != 'false';
    final savedAccent = await _db.pref('theme_accent');
    if (accentOptions.any((a) => a.id == savedAccent)) accent.value = savedAccent!;
    nowPlayingPanel.value = await _db.pref('now_playing_panel') != 'false';
    coverGradient.value = await _db.pref('cover_gradient') == 'true';
  }

  Future<void> setCoverGradient(bool on) {
    coverGradient.value = on;
    return _db.setPref('cover_gradient', '$on');
  }

  Future<void> setFloating(bool on) {
    floatingNav.value = on;
    return _db.setPref(_floatingKey, '$on');
  }

  /// A saved style, or the default if it's missing or damaged.
  static T _decode<T>(String? json, T Function(Map<String, dynamic>) from, T fallback) {
    if (json == null) return fallback;
    try {
      return from(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return fallback;
    }
  }

  final _saveTimers = <String, Timer>{};

  /// Changes show live while a slider moves, and are saved once it settles.
  void _saveSoon(String key, Object value) {
    _saveTimers[key]?.cancel();
    _saveTimers[key] = Timer(const Duration(milliseconds: 400), () => _db.setPref(key, jsonEncode(value)));
  }

  void setNavStyle(NavStyle style) {
    navStyle.value = style;
    _saveSoon(_navKey, style.toJson());
  }

  void setGlass(GlassStyle style) {
    glass.value = style.clamped();
    _saveSoon(_glassKey, glass.value.toJson());
  }

  /// [at] is set when the change came from another device, which keeps that device's time.
  Future<void> setProfileName(String name, {int? at}) async {
    final clean = name.trim().isEmpty ? 'Listener' : name.trim();
    profileName.value = clean;
    _nameAt = at ?? DateTime.now().millisecondsSinceEpoch;
    await _db.setPref('profile_name', clean);
    await _db.setPref('profile_name_at', '$_nameAt');
    if (at == null) onProfileChanged?.call();
  }

  Future<void> setProfilePhoto(String? path, {int? at}) async {
    profilePhoto.value = path;
    _photoAt = at ?? DateTime.now().millisecondsSinceEpoch;
    await _db.setPref('profile_photo', path ?? '');
    await _db.setPref('profile_photo_at', '$_photoAt');
    if (at == null) onProfileChanged?.call();
  }

  /// The name and photo, to send to another device of the same owner.
  Future<Map<String, dynamic>> profileToWire() async {
    final path = profilePhoto.value;
    String? photo;
    if (path != null) {
      try {
        photo = base64Encode(await File(path).readAsBytes());
      } on FileSystemException {
        // No photo to send.
      }
    }
    return {'name': profileName.value, 'nameAt': _nameAt, 'photoAt': _photoAt, 'photo': photo};
  }

  /// Takes another device's name and photo when its change is newer than ours.
  Future<void> takeProfile(Map<String, dynamic> m) async {
    final nameAt = m['nameAt'] as int? ?? 0, photoAt = m['photoAt'] as int? ?? 0;
    if (nameAt > _nameAt) await setProfileName(m['name'] as String? ?? 'Listener', at: nameAt);
    if (photoAt <= _photoAt) return;
    final photo = m['photo'] as String?;
    final old = profilePhoto.value;
    if (photo == null) {
      await setProfilePhoto(null, at: photoAt);
    } else {
      final dir = await getApplicationSupportDirectory();
      // A new name each time, since images are cached by path.
      final out = File(p.join(dir.path, 'profile_$photoAt.jpg'));
      await out.writeAsBytes(base64Decode(photo));
      await setProfilePhoto(out.path, at: photoAt);
    }
    if (old != null && old != profilePhoto.value) {
      try {
        await File(old).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    return _db.setPref('theme_mode', mode.name);
  }

  Future<void> setAmoled(bool on) {
    amoled.value = on;
    return _db.setPref('theme_amoled', '$on');
  }

  Future<void> setAccent(String id) {
    accent.value = id;
    return _db.setPref('theme_accent', id);
  }

  Future<void> setNowPlayingPanel(bool on) {
    nowPlayingPanel.value = on;
    return _db.setPref('now_playing_panel', '$on');
  }
}
