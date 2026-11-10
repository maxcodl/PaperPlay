import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Supergroup id of a channel or supergroup chat id (`-100…`); null otherwise.
int? supergroupIdOf(int chatId) {
  const base = -1000000000000;
  return chatId < base ? base - chatId : null;
}

/// One line of the setup results.
class BotCheck {
  const BotCheck(this.label, this.ok, this.detail, {this.added = false});
  final String label, detail;
  final bool ok;

  /// A channel joined the library.
  final bool added;
}

Future<void> _deleteDirs(List<String> names) async {
  final dir = await getApplicationSupportDirectory();
  for (final name in names) {
    final d = Directory(p.join(dir.path, name));
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// Removes the bot's local session and downloaded files.
Future<void> deleteBotData() => _deleteDirs(const ['td_bot', 'td_files_bot']);

/// Removes the user login session from versions that had one. It only clears
/// this device: the session stays listed in Telegram until ended there.
Future<void> deleteOldUserSession() => _deleteDirs(const ['td', 'td_files']);
