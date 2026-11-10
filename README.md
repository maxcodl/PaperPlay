# Paper Play

Unofficial, open-source music player that uses the Telegram API and is part of the Telegram ecosystem. It uses your Telegram channels as storage: a bot reads channels that already hold music, streams songs, keeps a size-limited offline cache, files songs into one main chat sorted by topic, uploads new songs, and fetches tags, covers and lyrics.

**Status:** early. Android and Windows. Reading, playback, filing and syncing between your own devices work against live Telegram.

## How it reads Telegram

Paper Play logs in as a bot, through TDLib. Bots can't list history, so it requests message IDs in order, at a speed you set, backing off when Telegram rate-limits it. TDLib uses MTProto, not the HTTP Bot API, so the Bot API's 20 MB download limit doesn't apply.

The bot reads any chat it's in. It only writes (posts, moves, deletes, uploads, makes topics) where it's an admin or the owner, so a friend can add their bot to your channel to listen without either library mixing into the other. Songs are never copied out of a chat the bot can only read.

**Optional: your own account.** You can log in your Telegram account in Settings, Telegram, Your account. It's used only for what a bot can't do: deleting posts older than 48 hours, and copying songs from any group or channel you're in (Channels, Copy from your chats). It reads and posts nothing else, and the session stays on that device.

You own the API keys, bot and chats, so this reduces risk to your account but can't rule it out. Keep a backup of your music somewhere else.

## Setup

On first launch, enter your `api_id` and `api_hash` from https://my.telegram.org, a bot token from @BotFather, and your channels as IDs, @usernames or post links. A link to the newest post is best, because it tells the bot where the channel ends. Keys and token are kept in the OS keystore on your device and are not built into the app. A second device on the same Wi-Fi with the same bot can leave channels empty and copy the library from the first.

## Building

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Runs on TDLib 1.8.70, built from source. Requires Flutter 3.41+. Build release APKs split by phone type, since a universal APK carries TDLib three times. With native libraries compressed, the arm64 APK is about 21 MB.

```
flutter build apk --release --split-per-abi --split-debug-info=build/symbols
flutter build windows --release
powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1
```

The last two make `Downloads\PaperPlay-Setup.exe`, a per-user installer (no admin rights).

To sign with your own key, create `android/key.properties` (gitignored) containing `signingFile=<path>`. That file needs `keystore.path`, `keystore.password`, `key.alias` and `key.password`. Without it, release builds use the debug key.

If you publish builds, add `--dart-define=CONTACT_URL=<your repo URL>`, since MusicBrainz asks clients to identify themselves.

## Behavior

- **Main chat:** pick one chat (Channels screen) and every song from your other admin chats is copied into it, oldest first, one version per song (best quality, then largest, then newest), into the topic it fits or the topic it had before. Topics are created when missing.
- **Telegram is only changed on purpose:** filing moves songs out of General (repost, check, delete the old post), Find duplicates and song delete remove posts from the main chat only, and uploads post new ones. Deleting a topic moves its songs to General first.
- **Speed:** every kind of background work (filing, uploads, reading, lookups, covers, copying with your account) has its own speed, 1 to 500 a minute. Telegram's flood waits are waited out and slow the work down.
- **Cache:** least recently played songs are evicted above the limit (default 2 GB). Pinned songs don't count towards the limit and stay until unpinned.
- **Metadata:** your edits > MusicBrainz > Deezer > iTunes > Telegram tags > filename, asked at the same time. Matches apply automatically only when the song's length is within 5 seconds, plus a score of 90+ on MusicBrainz or the same title and artist on the others; use "Find metadata" for the rest. Lyrics come from LRCLIB; covers from Telegram, the Cover Art Archive, Deezer or iTunes, fetched in the background for every song.
- **Song details:** format, quality and size show on each row. Lists can be sorted by size, quality, length, year and more, and long-press picks several songs.
- **Duplicates:** the same file posted twice appears once; versions of one song show as one row.
- **Sync:** your own devices on the same Wi-Fi, using the same bot, share favorites, playlists, tags and history, encrypted.
- **Backup:** a ZIP with song info, covers, playlists, favorites and settings, but not the music. API keys and the bot token are optional, and only ever stored encrypted with a password you choose (AES-256-GCM, PBKDF2). Treat the file as private: song and channel names are readable.

## Design

Material 3 Expressive look with Monet colours from your wallpaper on Android 12+, true-black dark surfaces, and player colours taken from each cover. Explanations sit behind small ⓘ buttons. Flutter's own widgets don't cover Expressive yet, so this uses the `m3e_*` community packages and `material_new_shapes`, with a custom wavy seek bar.

Judge scrolling on a release build (`flutter build apk --release`). Debug builds stutter regardless.

Nunito is included under the SIL Open Font License; see `assets/fonts/OFL.txt`.

## Built with

[TDLib](https://github.com/tdlib/td) via [handy_tdlib_next](https://pub.dev/packages/handy_tdlib_next), [just_audio](https://pub.dev/packages/just_audio), [drift](https://pub.dev/packages/drift), [MusicBrainz](https://musicbrainz.org), [Cover Art Archive](https://coverartarchive.org), [LRCLIB](https://lrclib.net), [Open-Meteo](https://open-meteo.com).

## License

MIT
