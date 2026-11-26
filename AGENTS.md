# PaperPlay Compose: rules for contributors and coding agents

Kotlin Multiplatform Compose app (Android + Windows desktop). Telegram bots and chats hold the music.
Read `README.md` and `CHECKLIST.md` before changing anything.

## Modules
- `core`: database, Telegram client, library, index, integrations
- `player`: playback engines (Media3 on Android, vlcj on desktop)
- `ui`: shared screens; `androidApp`, `desktopApp`: entry points

## Do not guess
- Read the code you change and the code that calls it. Search first, read line ranges.
- Reproduce or prove the cause (log line, test, stack trace) before fixing. A fix with no evidence is a guess.
- One change per commit. Keep diffs small; no drive-by refactors, no new dependencies without a reason.
- Never invent API fields (TDLib, Bot API). Check the schema or a live answer.
- A bug on the phone or PC can be proven from real data, when the owner agrees first (a library copy or backup too): copy `%APPDATA%\PaperPlay\library.sqlite` and query the copy, or run `adb shell dumpsys notification --noredact` for notifications. Do not write to the live file.
- A speed or smoothness claim needs a measurement before and after (`dumpsys gfxinfo` frame percentiles, a screen recording cut into frames, or a perfetto trace with `view gfx am input` categories). Several "fixes" this way changed nothing; the trace found the real cause.
- Do not commit a change until the build for it has finished and passed. If files you did not edit change under you (another session is working), leave them alone and commit only your own files.

## Build and test
- Android: `JAVA_HOME=<JDK 17> ./gradlew :androidApp:assembleDebug --no-daemon -q`, filter output for `^e:` and `FAILED`.
- After `adb install -r` run `adb -s <serial> shell cmd package compile -m speed -f io.max.paperplay.compose`. A freshly installed app is uncompiled and stutters badly (slowest 1% of frames 1 to 2 s against under 100 ms compiled); judge speed only on a compiled release build. Use the USB serial when `adb devices` lists the phone twice (USB and wifi).
- Tests: `./gradlew :core:jvmTest --no-daemon -q`. They must pass before a commit.
- Desktop run needs JDK 25.
- If you are told not to build or install, stop any build you started: stopping the task leaves its Gradle JVM running, so end that process too (only the one you started).
- One Gradle at a time. Do not build in a tree another person or agent is editing; use a separate worktree.
- Run `git status` before a build or release: a build copies every changed file, so another editor's unsaved work would be in it.
- `scripts\release.ps1` builds the Android release (installed on the phone when one is connected) and the Windows installer.
- All core tests pass (`:core:jvmTest`). Run only the tests asked for when told not to build.
- Do not stop Gradle or Java processes you did not start; another agent may be building.
- Before trusting a release script run, check `adb devices`: with no phone connected the script skips the phone install and says so.

## Testing on the phone
- `adb install -r` only; never uninstall the app (it holds the library and sessions). Launch it, record the screen or read device state only when the user asks or has asked you to measure; the phone locks itself during tests (`svc power stayon usb`, then `stayon false` afterwards).
- Telegram tests by hand (Bot API) use tokens from the git-ignored `.secrets/`; never print or commit a token, and delete or edit only the posts the user named.

## Code
- Files mix LF and CRLF line endings. A script that edits a file must keep the file's own endings (read, normalise, edit, restore), and backslash escapes (a tab, a regex word boundary) written through a shell heredoc can be mangled: use the Edit tool for those and build to check.
- Previews use `org.jetbrains.compose.ui.tooling.preview.Preview`; never add androidx `ui-tooling` to `commonMain`.
- No GPL code. No emojis in UI text.
- Never commit secrets (`local.properties`, keystores, tokens, Telegram sessions, logs with chat data).
- Do not delete or overwrite user data: library rows, Telegram posts, phone files. Deleting posts is irreversible; a post counts as gone only when the owner's account confirms it.
- Bots cannot see posts made by other bots. "Not found" from a bot proves nothing.
- A bot deletes only posts younger than 48 hours (its own, or ones you sent); older posts need the logged-in account. Do not try bots on older posts; say that the account is needed.

## Audio engine
- Own clean-room code only. Never copy, port or bundle code, binaries or assets from another app's APK; reading one to learn a technique is fine, the code is written from the technique.
- Third-party code only under MIT, Apache-2.0 or BSD. No GPL; LGPL only dynamically linked and only after asking.
- The Rust DSP core lives in `engine/` (tracked). `native/` is gitignored (TDLib), so do not put it there. Built `.so` files are not committed.
- Build with `cargo ndk -t arm64-v8a`, before Gradle and never at the same time as it.
- After `engine/` changed (also by a merge) rebuild `engine`, `usb_audio` and libusb before any phone build; the build stops when a library is older than its source, and only warns when one is missing.
- No allocation, locks or panics in the audio path; no panic across the FFI line. If the library fails to load, fall back to the Media3 pipeline and log it.
- Sound changes are judged by ear on the phone, level matched, against the previous build; mark `[~]` in `CHECKLIST.md` until heard working.
- Layout: `engine/src/eq.rs` (curve fit, Bass, earphone correction, 180 Hz split, level trims, limiters, A/B), `engine/src/extras.rs` (dynamic bass, de-esser, crossfeed, switched by option bits), `engine/src/lib.rs` (JNI only).
- Every piece gets a Rust unit test, and the test must fail when the fix is taken out (check it once). Keep the null test: flat curve, Bass 0 and no options give bit-exact output, also after the engine was on.
- No clicks: parameter changes crossfade or glide, switching on and off fades. Never clear delay lines while sound is playing.
- Headroom: output ceiling -1 dB true peak; the bass half sits lower than the output so its peaks do not make the output limiter duck the rest; limiters on bass hold longer than half a bass period (no gain movement inside a wave).
- A new engine setting goes the whole way: Rust, `lib.rs`, `EngineNative.kt`, `PlaybackCore`, applied in `EngineAudioSink.convert`, `PlayerEngine` (default does nothing, so the PC is untouched), `LazyPlayerEngine` (kept until the engine exists), `PlaybackController`, `CoreBackend` and `PlayerControls`, and the per-output snapshot (`eqSnapshot`/`onOutput`). UI goes in `EngineExtras`, which both the Settings page and the player dialog show.
- Compare with original needs something to compare: with a flat curve and Bass 0 the engine is bypassed and both sound the same.
- Earphone corrections come from AutoEq (MIT) ParametricEQ results; name the measurement source and rig in a comment. They are for wired earphones; earbuds have their own tuning.
- The PC mpv filter chain (`MpvFilters.kt`) is a separate copy of the older engine design; phone engine changes do not reach it. Change it only as its own step, with the PC tests.
- `JvmPlayerEngineTest` (VLC) can time out once; run it again before blaming a change.
- Plan and status live in the local `ENGINE_PLAN.md` (ignored); keep `CHECKLIST.md` in step.
- Desktop: the optional mpv engine uses `libmpv-2.dll` through JNA. LGPL build only (the file name contains `lgpl`), never in git (`desktopApp/src/jvmMain/resources/mpv/`); the Windows CI step pins the build and its SHA-256. VLC stays the default until the mpv engine is proven. Tests use `ao=null` so nothing is played aloud.

## Covers
- Covers are written only by `CoverService.writeCoverFile`: at most 1000 px, JPEG, named `c_<hash>.jpg` from the bytes, so songs of one album share a file. Never write or delete a cover file anywhere else.
- A cover file is deleted only when no song's `cover_path` uses it (`coverPathUses`). `packExistingCovers` (once, pref `cover_pack_v1`) and `removeUnusedCovers` (every start, files older than an hour) keep the folder small; they run in the background and log "covers: ..." lines.
- Backup, restore and sync follow `cover_path`; keep that column and the `covers/` folder, so they need no change.

## UI
- Match the neighbours first: copy the row, header, spacing and icon style of the nearest existing screen or list instead of inventing a new one. Reuse the shared composables and theme tokens (`MaterialTheme.colorScheme`, `AppIcon`, `LocalUiPrefs`); no hard-coded colours.
- Every navigation row, setting and tool has an icon from the Material rounded set, and the same icon means the same thing everywhere.
- A collapsible group is a normal row with an icon and a fold arrow, not a bare title. It must still show and work when the sidebar is narrow. The sidebar lists Tools, Playlists and From Telegram this way, so every list of items in it folds the same way.
- Separate groups with a divider or a section label, never by position alone. Settings and About sit apart from content and tools.
- Highlight the open page in every list that can open pages.
- Sidebar and settings headings follow the same groups; a new page names its group.
- Lay out for both phone and desktop widths; nothing may clip, overlap or need a horizontal scroll.
- Buttons and actions say what they do in plain words; no emojis, and a long action is confirmed or can be undone.
- UI changes: update `CHECKLIST.md` in the same change, and mark `[~]` until seen working.
- Keep composition light: no grouping, sorting or database work on the main thread (build lists in a flow on `Dispatchers.Default`), and do not read fast-changing state (queue sizes, progress) in a large composable, which redraws everything below it.
- Animations that move cards or covers use translation and fade only. A rotated or scaled layer that holds images uploads every cover to the graphics memory again each frame (measured: about 1,000 uploads in half a second, against about 100 without it).

## Behaviour that must hold
- No touch goes through anything: a sheet, bar or overlay takes the touches that land on it (`Modifier.blockTouchesBehind()` in `ui/.../app/BlockTouches.kt`); a list behind the player must never react.
- A library song is never removed because another device listed its post as gone (`index_gone_posts`): those lists were wrong on 25 Nov and a sync that trusted them removed real songs (1.22.0, 1.23.0). Only the deletion record of songs deleted by hand, and this device asking Telegram, remove songs.
- A song in a credit "A, B & C" is several artists; use `splitArtists` (core `metadata/Text.kt`) wherever artists are listed, linked or matched.
- A cover or album match is never taken from a compilation ("Bravo Hits", "Top 100"): use `isCompilationAlbum` and `pickExternal(..., allowCompilation = false)` for covers.
- Data that two devices both have is merged by one pure rule that gives the same answer on both sides (`remoteTagsWin`, `remoteLyricsWin`, `mergeSongData`); what was made by hand wins over what was found.
- Tags from Telegram can be wrong (title and artist swapped, "Version - Artists" as the title). Fix them in `fixSwappedTags` and `repairSplitNames` (`Scanner.kt`), never by hand in the DB; a repair that must run again on existing libraries gets a new pref key (`split_names_vN`) and bumps `tags_at` so it wins the sync.
- A song goes on Recently played after 30 s heard (`RECENT_AFTER_MS`), counted by playing time so seeking does not undercount; a private session (`PlaybackController.privateSession`) records nothing.
- A device the person disconnected by hand (`LanSync.held`) is never dialled by `autoConnect` or `addDiscovered` and its dials are refused until `connect` is called for it.
- True Audio (mpv exclusive output): seeks are coalesced and muted across the jump (`MpvPlayerEngine.seek`); no filters, so bit-perfect stays.
- The phone visualizer is fed in `EngineAudioSink.tap`, because Media3 skips audio processors for float output.
- Rewind: one press restarts the song, a second within 2.5 s goes back, the first song only restarts.
- The cache limit is one total shared by every Telegram store (`storeShare()`: limit / (2 + extra bots)). TDLib's `optimizeStorage` takes only `fileTypeAudio` and `fileTypeDocument` (there is no temp type; a wrong name fails the whole call). Never run it on the main bot: it would delete pinned songs; the main bot is cleared song by song (`deleteSongFile`). A file fetched only to read a cover is deleted after reading.
- Work that decodes whole songs (`AudioFeatureStore`) runs only while charging (`Platform.canRunHeavy`). Anything on a timer must say why its interval is safe for battery, and a repeated failure must back off and must not write the database each time.
- The audio thread feeds `AudioTap` only while a visual read it in the last 2 s (`AudioTap.wanted`), on both the engine path and the pass-through path in `EngineAudioSink`.
- Measuring CPU: the release build is `profileable` from the shell, so `simpleperf record --app io.max.paperplay.compose -g` works without a debug build; names come back through `androidApp/build/outputs/mapping/release/mapping.txt`. A debuggable build runs mostly interpreted and overstates every number.
- Never hold the whole chat index in memory (text, bytes or a JSON tree): it is about 40 MB and the phone heap is 256 MB. Use `JsonStream` and `FileAppender`.
- Read the whole library with `db.allSongsNow()` (or inside `stableRead`), never `allSongs().executeAsList()`; delete many songs in one `library.batch`.
- A chat's newest post and "complete" may be recorded only once every post up to it is stored: `pruneDeadRows` removes songs of posts it does not find.
- Delete a post only after the new one is confirmed: use `TdClient.sendAndWait`; TDLib answers a send before anything was sent.
- The thread that reads a device link must never write to it (`JavaLanSync.Peer.send` queues).
- Work that must outlive the window runs on the one `CoreBackend` of the services or on `services.scope`, never on a composition.
- A library transaction that reads before it writes starts with `lockForWrite()` (`library.batch` does it).
- Only posts Telegram itself said are deleted go to `IndexStore.markGonePosts`; never a guess, it deletes on linked devices too.
- Shutting down, restoring and erasing run on `LifeWork.app`, not on a screen's scope.
- Before a commit build the UI and both apps, not only `core`.
- Devices sync only with the same app version and `SYNC_FORMAT` (`LanSync.kt`). Raise `SYNC_FORMAT` when synced data changes its meaning; a new message that carries data goes into `SYNC_TYPES` (`JavaLanSync.kt`).
- Seconds of work (matching titles, reading thousands of rows one by one) run outside a transaction, and many writes go in small steps: whoever waits for the library may be the screen. Android uses WAL, so reads pass a writer; a write from the screen goes through `scope.launch` or `LibraryRepository.savePref`, never straight to the file. No database reads while drawing.
- A short code is never proven with a hash of it: pairing and network play use `CPace` (`pakeServer`, `pakeClient`), because whoever answers could try out every PIN.
- The decoder gives float whatever the depth of the music, so a DAC setting is picked with `UsbFormatNegotiator.pickForSource`; a fall back to Android's mixer is logged with its reason. Earbuds connected after a DAC win (`UnifiedUsbAudioSink.otherOutputWins`).
- Duplicates are ticked only when surely worse (`worseQuality` in `Duplicates.kt`); depth and rate are known only after playing, so a missing value says nothing.
- TDLib file ids belong to one client; check which client an update came from.

## Git
- Short plain commit messages. No tool or AI mentions, no trailers.
- Do not push unless told. Pull with `git pull --rebase --autostash origin main` first. Never bump the version by hand; the release bot does.
- Do not edit files another person or agent is working on; keep them out of your commits. Stage your own files by name; never `git add -A` on a folder another session is changing (a hunk of theirs that depends on an untracked file breaks a clean build).
- If `git push` is rejected because the release bot pushed, merge `origin/main` into `main` (no rebase and no force), push `main`, then fast-forward `beta`. Push `main` and `beta` one after the other, not at once.

## Docs
- Only `README.md`, `CHECKLIST.md`, `CHANGELOG.md` and `AGENTS.md` are tracked `.md` files.
- Keep `CHECKLIST.md` current: `[x]` seen working, `[~]` built but not tried, `[ ]` open.
- Local notes (`HANDOVER.md`, `CONTEXT.md`) stay git-ignored.
- **Report everything to `HANDOVER.md`.** After each set of changes and before you stop, add a dated section there: what changed (commit hashes), what was checked and how (tests run, device or log evidence) and what was not, what is left unpushed, open bugs and their evidence, the exact next steps in order, and anything another session left uncommitted that you did not touch. Another agent must be able to continue from that file alone. Mark `CHECKLIST.md` in step.
