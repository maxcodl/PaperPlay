# Changelog

All notable changes to PaperPlay are listed here, newest first. Each stable release adds its section automatically.

## [1.23.2] - 2026-11-26

### Other changes
- Continuous corners like iOS for every part that follows the corner settings ([`9b95b5a`](https://github.com/maxcodl/PaperPlay/commit/9b95b5a31732fc5094daa0f228f9a7ce682ee1f2))
- Tray menu ends above the clicked icon, also with a taskbar that hides itself ([`c756707`](https://github.com/maxcodl/PaperPlay/commit/c756707069bbd5bdbd001fe35d3d39bf8a4a0ca8))
- Tray menu opens above the taskbar ([`30c2cba`](https://github.com/maxcodl/PaperPlay/commit/30c2cbaf874d8818d67d06c981a57b5ea2f397b1))
- Tray menu: no empty space below Quit ([`8d6e99a`](https://github.com/maxcodl/PaperPlay/commit/8d6e99a43f684cae5847b5e896c162be0881cb08))
- PC profile uses the new profile page, in two columns on a wide window ([`273f6c4`](https://github.com/maxcodl/PaperPlay/commit/273f6c4361f2e8768f17db79d66c3cc693436129))
- PC sidebar: no scrollbar over the icons ([`6375b7d`](https://github.com/maxcodl/PaperPlay/commit/6375b7d8c942afcfb64acf2823840b9b2bdb962e))

### Maintenance
- 26 Nov work, and songs are never removed for another device's gone list ([`ea436e3`](https://github.com/maxcodl/PaperPlay/commit/ea436e37e71459fe455c0470183542e1e014f000))

**Full changes:** [v1.23.1...v1.23.2](https://github.com/maxcodl/PaperPlay/compare/v1.23.1...v1.23.2)

## [1.23.1] - 2026-11-26

### Other changes
- Revert "A post another device found gone from Telegram leaves this library too" ([`5e98111`](https://github.com/maxcodl/PaperPlay/commit/5e9811161bd5f971c76f72ec4fe1486960cdfe10))

**Full changes:** [v1.23.0...v1.23.1](https://github.com/maxcodl/PaperPlay/compare/v1.23.0...v1.23.1)

## [1.23.0] - 2026-11-26

### Added
- Rewrite Android Profile page for Default and Modern styles ([`d98120f`](https://github.com/maxcodl/PaperPlay/commit/d98120fd5b2a8093e6841c449ddefb23478b4835))
- Modern Android UI foundation, tokens, backdrop host, and prefs ([`6f1719e`](https://github.com/maxcodl/PaperPlay/commit/6f1719e1e7bb9403a34a87e134a6782baaddb8e5))

### Other changes
- Simplify Settings Appearance App style selector ([`267e1e1`](https://github.com/maxcodl/PaperPlay/commit/267e1e15066da242cad55d346d936c2f83d65017))
- Unify mini-player hide and add Modern swipe-down hide and expand gestures ([`7a389e7`](https://github.com/maxcodl/PaperPlay/commit/7a389e77487d2e6c05e0df3765ca7062d2174ab8))

**Full changes:** [v1.22.0...v1.23.0](https://github.com/maxcodl/PaperPlay/compare/v1.22.0...v1.23.0)

## [1.22.0] - 2026-11-26

### Improved
- Unify ambient and background animations on shared visibility-gated clock ([`7ca63ef`](https://github.com/maxcodl/PaperPlay/commit/7ca63ef59b21d29b1b579fad548d635ece510610))
- Share skeleton shimmer clock and unify list and Home animations ([`eda2f41`](https://github.com/maxcodl/PaperPlay/commit/eda2f417dcecad92dc6d60e54c36bb51c49b4cc7))
- Stage FullPlayer content and defer wave/glass effects until settled ([`17adb8f`](https://github.com/maxcodl/PaperPlay/commit/17adb8fc82729e41423ecc2b8f675b218fa69e84))
- Defer Modern glass blur during sheet slide and prewarm cover/output ([`4f41447`](https://github.com/maxcodl/PaperPlay/commit/4f4144703bc23dcc188073f45719ac84289f5e5c))
- Remove SongRow BoxWithConstraints, hoist regex, and optimize CoverImage/skeleton ([`de71dbc`](https://github.com/maxcodl/PaperPlay/commit/de71dbc5c2a9d88da9909b504b6b7d57e254411e))
- Stabilize LocalPageTop state and defer g0 reads out of MainShell ([`b0fe07d`](https://github.com/maxcodl/PaperPlay/commit/b0fe07ddd447d8ebaa670fb9f4a0beaf207a8ea1))
- Compute CoverSeeds off main thread with per-URI Compose state ([`24a5e2c`](https://github.com/maxcodl/PaperPlay/commit/24a5e2c8d21f3f38c4208b7b15385b89484ebbcb))
- Eliminate per-buffer PEQ re-upload and allocations on audio path ([`8d19b62`](https://github.com/maxcodl/PaperPlay/commit/8d19b62814fb25642990105e7f78f187cbab41a7))

### Added
- Add unified Motion tokens, shared AmbientClock, system reduce-motion, and Motion Lab ([`a4bfd22`](https://github.com/maxcodl/PaperPlay/commit/a4bfd22821778f41fb398dc19256a8ec012678bb))
- Add layer-based shared cover transition synced to sheet progress ([`d0c7669`](https://github.com/maxcodl/PaperPlay/commit/d0c7669eff89db99581e13e1e5ae7a385205b908))
- Add PlayerSheetHost, unified drag gesture, back cancel, and system bar tint ([`b843b5e`](https://github.com/maxcodl/PaperPlay/commit/b843b5e2af08133f2ca461b2c3443783e8658898))
- Add PlayerTransitionController state machine and motion tokens ([`9e1de46`](https://github.com/maxcodl/PaperPlay/commit/9e1de467be067035cf216c2ccf2cf14524a51462))

### Fixed
- Order drawWithContent before layerBackdrop and decouple Modern glass settle ([`3e33571`](https://github.com/maxcodl/PaperPlay/commit/3e335715ea61329845372b6d2a893f474bc2d190))
- Add covered hysteresis and keep underlying page mounted ([`76de5f6`](https://github.com/maxcodl/PaperPlay/commit/76de5f676a808efa15d7ed43d2b9bfe5fe01c584))
- Use critically damped sheet spring and clamp translation ([`c7560d1`](https://github.com/maxcodl/PaperPlay/commit/c7560d1f550e24df78104be34ce61405ae4a0695))
- Raise AppEvents cover-cache clear threshold to TRIM_MEMORY_BACKGROUND ([`18e795e`](https://github.com/maxcodl/PaperPlay/commit/18e795ebc1012c5256d1f399b7bb9da7e018e15a))
- Publish CoverSeeds in mutable snapshot and unblock FileCoverLoader ([`0e505b9`](https://github.com/maxcodl/PaperPlay/commit/0e505b985a73850e7c908b082ca2a0c54ac5804b))
- Restore full-bounds diagonal shimmer draw in HomeSkeleton ([`0cfe278`](https://github.com/maxcodl/PaperPlay/commit/0cfe27885dd8a509764825d8fc5ff5bd300dc83b))
- Harden Rust EQ reconfigure/NaN/zero-alloc JNI and UAC1 probe volume fallback ([`98fa7c2`](https://github.com/maxcodl/PaperPlay/commit/98fa7c2eecb7718ce7c3c47a5b74811de4a98af2))
- Dispatch JvmPlayerEngine playing work to vlc-cmd and guard post-release cmds ([`0707be3`](https://github.com/maxcodl/PaperPlay/commit/0707be391a2c7a986b47a39b78e48805fabc6383))
- Clear mpv filters in exclusive mode, free ctx on init failure, and stop 4Hz idle poll ([`d99aaf8`](https://github.com/maxcodl/PaperPlay/commit/d99aaf83eb96eb6d73a4195a832f7f504a89b015))
- Remember desktop AppEnv, scope mini window state, and remove taskbar poll loop ([`8f0760d`](https://github.com/maxcodl/PaperPlay/commit/8f0760de331d07637413216707e57e0aa4cae30a))
- Close Skia image handles on desktop, trim cover cache, and stop truncating logcat ([`1321366`](https://github.com/maxcodl/PaperPlay/commit/13213664cc747c3511b7f721095ffccdd8903ef8))
- Pause idle BitPerfect/Standby animations and block touches behind Onboarding ([`b45889e`](https://github.com/maxcodl/PaperPlay/commit/b45889ef188c583b4c1f94087dfeb58b023884dd))
- Throttle AddressBook.learn writes and clear Netplay external sources on leave ([`669d8d7`](https://github.com/maxcodl/PaperPlay/commit/669d8d720270f7b795010a522f4040cc40f7b417))
- Guarantee AppServices runtime teardown, lazy close, and flushCache draining ([`7512417`](https://github.com/maxcodl/PaperPlay/commit/75124174959f1f2447ccacc606f92e5913ade94b))
- Synchronize Uploader sent map and remove O(N^2) enqueue scan ([`c68becf`](https://github.com/maxcodl/PaperPlay/commit/c68becf8cf17936befdf3388e4f266de86174c05))
- Synchronize BotPool clients map and shut down failed extra-bot sessions ([`194402c`](https://github.com/maxcodl/PaperPlay/commit/194402c726466b9028a611b1f40a573e348f93d4))
- Synchronize CoverService giveUps, fix upgrade queueing, and reuse album covers ([`89bb107`](https://github.com/maxcodl/PaperPlay/commit/89bb107a6a7ab2784466a2cedebf719e243420c4))
- Stop UsbAudioManager volume poll spam, ContentObserver leak, and duplicate receiver ([`573d659`](https://github.com/maxcodl/PaperPlay/commit/573d65990867840d0a98602907af771d123ecb90))
- Prevent handle double-free and wake lock leak in legacy UsbAudioStreamer ([`a983cfe`](https://github.com/maxcodl/PaperPlay/commit/a983cfeebe1f7fdd19af78170003a04d4b4d7546))
- Avoid MainActivity leak in watchActivity and guard UpdateInstallReceiver on API < 33 ([`8073aa4`](https://github.com/maxcodl/PaperPlay/commit/8073aa43e6b0d291105992fe3102911f13671987))
- Clear activePlayer on destroy and detach old loggingListener on rebuild ([`16ce9d2`](https://github.com/maxcodl/PaperPlay/commit/16ce9d2be70862ab6f7528cf50ebc68e9c102f95))
- Preserve queue items across bit-perfect rebuild on STATE_ENDED ([`35cc3f9`](https://github.com/maxcodl/PaperPlay/commit/35cc3f994ebfe75272b0ae67a9477b5deba2f8c1))
- Keep UsbThreadHelper in ProGuard and clear JNI_OnLoad exceptions ([`ef5c611`](https://github.com/maxcodl/PaperPlay/commit/ef5c61178e9ef3c3ebf78ded972be0c5d28089fa))

### Other changes
- Log: what downloaded each minute and why, and where the song storage is ([`f022542`](https://github.com/maxcodl/PaperPlay/commit/f02254208cc957738ba9ead4786bf8c6f02c7480))
- Duplicates: copies whose length was never read are found by their file size ([`8c8fb8e`](https://github.com/maxcodl/PaperPlay/commit/8c8fb8e8e0fbfd3746ea674009e944803a79e55e))
- A post another device found gone from Telegram leaves this library too ([`9dd25eb`](https://github.com/maxcodl/PaperPlay/commit/9dd25eb7afd502fdf0c451e3740f0b2978d8bee8))
- A device that another one drives stops controlling that one, so neither shows the other as playing ([`d068241`](https://github.com/maxcodl/PaperPlay/commit/d068241695b7a56b61d1438506c64374790cea3f))
- Standby turns within half a second: the raw motion sensor instead of the slow gravity sensor ([`b523a5f`](https://github.com/maxcodl/PaperPlay/commit/b523a5fba0835c6d73b126fd746c046fdc87f772))
- Standby: the rotation button shows whether it is on, and says so when tapped ([`ca44eb3`](https://github.com/maxcodl/PaperPlay/commit/ca44eb38527a1c8cea6c72586567cdf5378d2129))
- Standby: the rotation button fades out like the settings button ([`da068eb`](https://github.com/maxcodl/PaperPlay/commit/da068ebf7ecc598a248aa0ff87e4237d278f2c0f))
- Standby turns the right way, also when the phone leans back, and no longer flips near 45 degrees ([`db99928`](https://github.com/maxcodl/PaperPlay/commit/db999286904fb60b7bdb464b7b1154fd08391446))
- Add deep-buffer, PLL, 144Hz, and 64-band Standby visualizer tests ([`678ac38`](https://github.com/maxcodl/PaperPlay/commit/678ac38b74e445bd56136087deb1926e660a25cd))
- Upgrade Standby refresh rate lock and 64-band Bezier/capsule visuals ([`815bdde`](https://github.com/maxcodl/PaperPlay/commit/815bdde30b0c62e64dddf24e94fe9e28cab71403))
- Fix AudioTap deep-buffer history, PLL clock, and display latency sync ([`a12b8be`](https://github.com/maxcodl/PaperPlay/commit/a12b8becaf09c863df94b1ff3601d7f5011fd50a))
- Finalize AudioTap tests and update checklist for Standby visualizer ([`514e6e3`](https://github.com/maxcodl/PaperPlay/commit/514e6e36bd9c78ac3c8d9646a0b677ae79edc1a8))
- Add offline reference analyzer and objective AudioTap/Standby tests ([`c57f80d`](https://github.com/maxcodl/PaperPlay/commit/c57f80d9305b728c8e46888566adda93d63ff04f))
- Retune StandbyVisual smoother, add sync offset slider and diagnostics HUD ([`bd6261a`](https://github.com/maxcodl/PaperPlay/commit/bd6261a1cf4315c71939c95f1fac29a7c6659da5))
- Redesign AudioTap with multi-res FFT, time-domain bass, and region AGC ([`1738f31`](https://github.com/maxcodl/PaperPlay/commit/1738f31338d5a42c925db546ff22a9e86f14a9f8))
- Update checklist for desktop motion rewrite ([`5e71e2e`](https://github.com/maxcodl/PaperPlay/commit/5e71e2e9d40cea29609f31e62f8a0e0ca16206b6))
- Pass motion bench args through Gradle desktopApp run ([`e21a192`](https://github.com/maxcodl/PaperPlay/commit/e21a19200d8723b95e4884c99fddfe8f168ea534))
- Add desktop frame metrics, Motion Lab desktop suite, and scripted benchmark ([`3872a05`](https://github.com/maxcodl/PaperPlay/commit/3872a05a3d7c6702cd4eea762832d1f38117b868))
- Eliminate desktop first-frame flash, wire file drop drag state, and gate idle loop ([`910a89b`](https://github.com/maxcodl/PaperPlay/commit/910a89b40b4deacfa1dbe9f516255350ebddb555))
- Wire desktop shell, now playing, mini window, and lists to motion system ([`fa41875`](https://github.com/maxcodl/PaperPlay/commit/fa418758b5444b3d202a4338a4b232440158946b))
- Add desktop input, tooltip, smooth wheel scroll, scrollbar, and drop overlay ([`df3cf78`](https://github.com/maxcodl/PaperPlay/commit/df3cf78212f6a88dc43398d7494a12af9475f786))
- Add desktop motion tokens and resize-resilient transitions ([`a245f4f`](https://github.com/maxcodl/PaperPlay/commit/a245f4fef78d1d599796cfb21521c9d60d103210))
- Ui: remove Standby Rhythm fallback and timer pulses, wire onset detector ([`6d94582`](https://github.com/maxcodl/PaperPlay/commit/6d9458225af4379538cf02b8abc0d05fcb03a18d))
- Audio: feed AudioTap on desktop mpv and vlcj via synced silent shadow decoder ([`f033d57`](https://github.com/maxcodl/PaperPlay/commit/f033d579315ef4c4dbb4d9e69148ae01f98f3fd8))
- Audio: feed AudioTap from all Android normal, engine, API34, and USB paths ([`2500773`](https://github.com/maxcodl/PaperPlay/commit/2500773dfafb2997d97a15c96adc35f16c809dc2))
- Audio: schedule AudioTap by playout clock, decimate high rates, add onset detector ([`6ead557`](https://github.com/maxcodl/PaperPlay/commit/6ead5577cb90b9053714f9ef11a7711e8ec6fda6))

**Full changes:** [v1.21.6...v1.22.0](https://github.com/maxcodl/PaperPlay/compare/v1.21.6...v1.22.0)

## [1.21.6] - 2026-11-25

### Other changes
- Opening a Spotify playlist no longer waits for the matching, which is also about six times faster ([`1597fe9`](https://github.com/maxcodl/PaperPlay/commit/1597fe946c447ecb1bf2e5bead1fb1966ebb7404))
- Index keys are worked out before the write, in smaller steps ([`792952b`](https://github.com/maxcodl/PaperPlay/commit/792952b6b006f2a860c1dc7d5c257bb7919f46e4))

**Full changes:** [v1.21.5...v1.21.6](https://github.com/maxcodl/PaperPlay/compare/v1.21.5...v1.21.6)

## [1.21.5] - 2026-11-25

### Other changes
- Online build names the tests that failed ([`df01374`](https://github.com/maxcodl/PaperPlay/commit/df01374f7ea2213b42ca2c94e9d1c45d3a2dc417))
- USB ring buffer: never reports more bytes than it holds while it is cleared ([`b8f6dee`](https://github.com/maxcodl/PaperPlay/commit/b8f6deeb53a5983c6a4b8b5518ca024a85fa4fa8))
- Missing list: one line and one button per song, possible matches first ([`81f55a7`](https://github.com/maxcodl/PaperPlay/commit/81f55a7fe2f178fae86a4321dc69870f401ea8e4))
- Spotify matching: a title that was cut off matches by its start, artist and length; no second copy is fetched of a song that is here ([`c15b8e0`](https://github.com/maxcodl/PaperPlay/commit/c15b8e0bd04c351d38b3f2d3706fa37addc0aacb))
- Music folders: folder picker on the phone, the path box is second choice, whole drives work ([`acf362e`](https://github.com/maxcodl/PaperPlay/commit/acf362eade2eae1cc4c9a8f91f95c3b64379da7a))
- PC folder window opens in front, and cancelling it opens no second one ([`6f0effb`](https://github.com/maxcodl/PaperPlay/commit/6f0effb73d268c88f85b47c880ed540b1f8e64ba))
- New songs join their Spotify playlists at once; the missing list offers songs of the library ([`989108a`](https://github.com/maxcodl/PaperPlay/commit/989108a91519ec0030d4e2ceef0af4f1cbbb890c))
- Spotify matching: artist lists, film credits, version words and accents in a title no longer hide a song ([`18f4093`](https://github.com/maxcodl/PaperPlay/commit/18f409378a7a5ef9be43ffddd7b1b7dd69b22e24))

### Maintenance
- Spotify matching and folder picker ([`7cd46ca`](https://github.com/maxcodl/PaperPlay/commit/7cd46ca2ca3e64e86749055728fce1def558b0e2))

**Full changes:** [v1.21.4...v1.21.5](https://github.com/maxcodl/PaperPlay/compare/v1.21.4...v1.21.5)

## [1.21.4] - 2026-11-25

### Other changes
- Tests are back in the online build, in a job of their own ([`a5d8964`](https://github.com/maxcodl/PaperPlay/commit/a5d8964b2327e8b4690ce2d567b6f13663e9376e))
- Old DAC mode asks for a plugged in DAC once ([`6a7eb08`](https://github.com/maxcodl/PaperPlay/commit/6a7eb08846e708b91d6a2f8a82343ba907fead0a))
- Tests: the USB chain test also passes with Windows line ends ([`e00e600`](https://github.com/maxcodl/PaperPlay/commit/e00e600484b5a2e56c4c19bcda964aa0c96b06aa))
- Tests: unfaked Telegram requests are answered at once ([`b2389d8`](https://github.com/maxcodl/PaperPlay/commit/b2389d8b8a138c3dcf417bc49c7927e8fcc1c1a2))
- Settings changed on the screen no longer wait for another writer ([`02179be`](https://github.com/maxcodl/PaperPlay/commit/02179becf730ba179e1f05bc1a1f4deee28e201e))
- Pairing and network play PINs can no longer be tried out by the device that was dialled ([`d0e65f8`](https://github.com/maxcodl/PaperPlay/commit/d0e65f85b85d974218ee9e1fd00e74d3bc59face))
- Sync is blocked between different app versions, with a force button and a switch ([`329f953`](https://github.com/maxcodl/PaperPlay/commit/329f95390ca8bf8ddc4b7ab6fa05831c5812f782))
- Phone: screens read the library while something else uses it ([`f467064`](https://github.com/maxcodl/PaperPlay/commit/f4670646ee14d450300e492824d6975eaedcb726))
- Index: the library stays free while titles are compared with it ([`6725ce2`](https://github.com/maxcodl/PaperPlay/commit/6725ce2b316ec64a8802f3067922423b4bbd84df))
- USB: earbuds connected after the DAC keep the music until they are gone ([`3318cf3`](https://github.com/maxcodl/PaperPlay/commit/3318cf3f3fcf5dbc03110b17324caacf62d6ab57))
- USB: music decoded as float goes to the DAC's 24 bit setting instead of Android's mixer ([`41a2f4f`](https://github.com/maxcodl/PaperPlay/commit/41a2f4f1df966d96eff1f7e09d9774de55956e34))
- Spotify review: taking a match no longer waits on the main thread ([`7dd0830`](https://github.com/maxcodl/PaperPlay/commit/7dd0830a94d21ff555421c77ff023e84f38faed5))
- Duplicates: a smaller lossless file, another version or an unplayed better copy is no longer ticked ([`24a7e5b`](https://github.com/maxcodl/PaperPlay/commit/24a7e5bec1b87af259fcb6bddaa4c062198c76df))
- Index: only the right song counts as missing from a Spotify list, not every song with its title ([`f2af3c8`](https://github.com/maxcodl/PaperPlay/commit/f2af3c825433dca27661676b9744a7f67f66ceb2))
- USB: a DAC that is plugged in is asked for once, and allow can be tapped again after a no ([`ce9bb3d`](https://github.com/maxcodl/PaperPlay/commit/ce9bb3de29b6fdeb893c99fbfc35764724054425))
- Phone build stops when a native library is older than its source ([`fd1ff8d`](https://github.com/maxcodl/PaperPlay/commit/fd1ff8db3f398ff33a519ce78ea5e961c3760bd8))
- Song info lookups reload the library less often ([`1923e7c`](https://github.com/maxcodl/PaperPlay/commit/1923e7c0dfe112d7a1aba983a845b49d733bda1e))
- Scan: a repeated post is no longer counted as an added song ([`8e95a39`](https://github.com/maxcodl/PaperPlay/commit/8e95a391ca92a6a284a6dd63e254b6f404c58ce6))
- Basic groups: a missing post number is not taken as deleted ([`0443345`](https://github.com/maxcodl/PaperPlay/commit/044334569d40914843673b5b9605d42443e1e9ea))
- USB: song endings are no longer cut when the next song has the same format ([`d4e4cc0`](https://github.com/maxcodl/PaperPlay/commit/d4e4cc0979936293956ce0255f420f22044bbf19))
- Copying library-only songs goes on when the page is left ([`633ee5d`](https://github.com/maxcodl/PaperPlay/commit/633ee5d310436ef26de5331e9aa42770ecfe3c69))
- The next suggestion looks at recent listens only ([`290bf9b`](https://github.com/maxcodl/PaperPlay/commit/290bf9be7a6b1fda1321e3a7986b64e5ee8454fd))
- Picking a cover or profile photo no longer reads it on the main thread ([`b8a9674`](https://github.com/maxcodl/PaperPlay/commit/b8a96744a8b4f0644d93c2196edd3c94cb9b460b))
- USB: sound goes on after a fault, the permission question is asked once, play works after switching at the end ([`1b04e67`](https://github.com/maxcodl/PaperPlay/commit/1b04e67946593448e8d9f787d9567ffb6ceedff1))
- USB: a sample cut by a full buffer no longer shifts the ones after it ([`f397c51`](https://github.com/maxcodl/PaperPlay/commit/f397c510dbdbef6f3b8167d3b8fbc9848eb4bcbe))
- Backup keeps the account closed while copying it, unsent listens are kept, folder copies off the main thread ([`2dfa84a`](https://github.com/maxcodl/PaperPlay/commit/2dfa84a1be79deb4a625f5a03de0efe9fa1b0959))
- Chats page opens without reading the library on the main thread, the log copy keeps every line ([`ae26479`](https://github.com/maxcodl/PaperPlay/commit/ae26479b42c7c036ee69c0b8f94348b093bb1d5f))
- Restore and erase finish when the window is closed, choosing a backup no longer freezes ([`6667bf2`](https://github.com/maxcodl/PaperPlay/commit/6667bf2a88aacccea8cc95156f04a71edb67b137))
- PC: the window no longer redraws everything on each song, skipped songs do not block the next ([`2ab989c`](https://github.com/maxcodl/PaperPlay/commit/2ab989ca81a2f894df523fa7a1dc39d31cf0490f))
- PC package: equalizer maths and Normalise are in it, updates clean up old files ([`1404ec9`](https://github.com/maxcodl/PaperPlay/commit/1404ec9958a57e1a5f27b13b07b831731f5b3e17))
- Lyrics: busy sources are asked again, hand-picked lyrics stay; art lookups too ([`187104e`](https://github.com/maxcodl/PaperPlay/commit/187104eb59a9ab96cb923a8ad9f5f9fe31efda0e))
- Mood scan: lyrics of the right version only, songs stay unscanned when a service is busy ([`bd543ab`](https://github.com/maxcodl/PaperPlay/commit/bd543ab5b6621b2113813455e2b3c3093a95a855))
- A Spotify track matched by hand stays matched ([`638bfdc`](https://github.com/maxcodl/PaperPlay/commit/638bfdceb2b374d001c1e21a2894cd71667acadb))
- Spotify: two refreshes at once no longer end the login ([`88f5446`](https://github.com/maxcodl/PaperPlay/commit/88f5446d368a70ed1636b8fb13d5969be334a9a2))
- Duplicates page builds again ([`d899ea0`](https://github.com/maxcodl/PaperPlay/commit/d899ea0736179f596319c67a55c1fcf53d2a8a91))
- Auto filing waits for Wi-Fi or power and stops when it may not post ([`e2397f0`](https://github.com/maxcodl/PaperPlay/commit/e2397f078ce3cbdc3a501a9ef301fb22b7d45428))
- Updates: no endless install attempts, downloads go on, install works on Android 8 to 12 ([`68d5bf7`](https://github.com/maxcodl/PaperPlay/commit/68d5bf7392bd55027e3641321c8351efd77ff298))
- Duplicates page: a deleted post no longer counts as the copy that stays ([`2e47539`](https://github.com/maxcodl/PaperPlay/commit/2e47539dd72b1ff9fd1606d96722453428ab15a4))
- Closing the library waits for running work ([`5785817`](https://github.com/maxcodl/PaperPlay/commit/57858174c85f9abbac0a1c4158715c349e5ff0ce))
- A failed update install shows a message instead of crashing ([`4430876`](https://github.com/maxcodl/PaperPlay/commit/44308760788a9d157195d3076a79bb9f3448ab02))
- A cover file cut short is written again ([`f7d99c1`](https://github.com/maxcodl/PaperPlay/commit/f7d99c1e07566cfe029083e2f216844c2de0c519))
- Looking songs up again keeps changes made meanwhile, long reads are stable ([`1009e86`](https://github.com/maxcodl/PaperPlay/commit/1009e867b2b0432fe92128595cd614fc0a792701))
- Auto filing keeps the original when the new post is another file ([`403dd79`](https://github.com/maxcodl/PaperPlay/commit/403dd79b160580f120d71482f3aefafab84151d3))
- A session ended from another device can be logged in again ([`579fa10`](https://github.com/maxcodl/PaperPlay/commit/579fa10c7df38e5ea740e8b5fcd883b0037ce8cb))
- A slow upload is not sent a second time beside itself ([`1e8475e`](https://github.com/maxcodl/PaperPlay/commit/1e8475e1dcf896442b977e145386af7937ae94f3))
- Indexing: pause holds, flags wait for the end of a read, fewer library reloads while scanning ([`1d3afe9`](https://github.com/maxcodl/PaperPlay/commit/1d3afe98a27ea5d5a758f0e9f93a358c96185982))
- Previews no longer clear the song being streamed ([`e836e04`](https://github.com/maxcodl/PaperPlay/commit/e836e0494614b433593608dab96b014ca24b6c29))
- PC: library writes wait for each other instead of failing ([`be45fe4`](https://github.com/maxcodl/PaperPlay/commit/be45fe45e09dc6317e74d7e7cd79db7f8abf0bb5))
- Faked announcements no longer push saved addresses out ([`56fd05d`](https://github.com/maxcodl/PaperPlay/commit/56fd05d6de7b3dc8e2ce239f9f3d04fd0d82072a))
- Merging with a linked device keeps changes made meanwhile, refused deletions are not stored ([`4a75caa`](https://github.com/maxcodl/PaperPlay/commit/4a75caa87a8147c6cb1a4afc5a2be1fce6049719))
- New index posts no longer start a whole exchange ([`e808e14`](https://github.com/maxcodl/PaperPlay/commit/e808e140b0c858b9f37bf5c6debaeb158ec5f96b))
- Songs deleted on one device do not come back from the other ([`fde9235`](https://github.com/maxcodl/PaperPlay/commit/fde9235bb78156fd34d298c9d95920614729eab7))
- Strangers on the network can no longer make the app take big blocks of memory ([`06e2a5c`](https://github.com/maxcodl/PaperPlay/commit/06e2a5cacafe627ad4b1c2ac46cb771ef01c9372))
- First setup connects once, a corrected token is used, a slow first login goes on ([`2b972f8`](https://github.com/maxcodl/PaperPlay/commit/2b972f8379ba6c4fbfde709c2782c60b6b0851b4))
- File updates of one bot no longer touch songs of another ([`c4fb55c`](https://github.com/maxcodl/PaperPlay/commit/c4fb55c575c13aee5242af3229d7ae82a8efdd6f))
- Listening time goes to the right song when a new queue starts at the same place ([`cda0a26`](https://github.com/maxcodl/PaperPlay/commit/cda0a266258788f1e10dd47b4c25e83c1ef1c053))
- Sleep timer, jobs, scrobbling, log and mini player go on when the window is hidden ([`64b0af5`](https://github.com/maxcodl/PaperPlay/commit/64b0af503bb75bca7a3fe481861934ea7c6a4b27))
- Restore keeps listening time, EQ presets, play log and the account login ([`a3234fd`](https://github.com/maxcodl/PaperPlay/commit/a3234fda07f144aa7264eba90f09f211fec44057))
- Deleting a repeat row no longer deletes the song ([`73732b0`](https://github.com/maxcodl/PaperPlay/commit/73732b0ecdcbbfce57d3492d66442479d5afce9f))
- Recovery waits for Telegram to confirm a copy before deleting, index sync and deleted song corrections ([`fd4034c`](https://github.com/maxcodl/PaperPlay/commit/fd4034c282c54226f559ae27105c78b21b78ecf1))
- Saved index streamed, link deadlock, safe index progress, deleted songs, listening time synced between devices ([`442e19a`](https://github.com/maxcodl/PaperPlay/commit/442e19ab6779ae81433920e79eda6ab6c0ca1d42))
- Crash diagnostics developer option, readable stacks in release builds ([`8272a07`](https://github.com/maxcodl/PaperPlay/commit/8272a0791adefa468f5f7f5251289244958f42dd))

### Maintenance
- Pairing, saving and tests ([`23b6cc3`](https://github.com/maxcodl/PaperPlay/commit/23b6cc317f86f46ccae15ea91b791322cc5476e7))
- Earbuds over the DAC is decided ([`8a363da`](https://github.com/maxcodl/PaperPlay/commit/8a363da7c088ea8841e3f5e6ba02d6a4814e5cdf))
- State after the audit, DAC, database and version check ([`a0c5d7d`](https://github.com/maxcodl/PaperPlay/commit/a0c5d7d5ff0b5a3a1ecf448ed820b8ff8ffd8b4c))
- Version check for sync ([`546916e`](https://github.com/maxcodl/PaperPlay/commit/546916eb6d92198d79c692449944c1fe84cb9af6))
- Database freezes ([`487ee58`](https://github.com/maxcodl/PaperPlay/commit/487ee5888a4b4a13c660d70508ccfe90144924de))
- DAC state ([`71f4735`](https://github.com/maxcodl/PaperPlay/commit/71f47356f5d06622842e9833ea92a63f11fe4379))
- Duplicates rules ([`17cf1e3`](https://github.com/maxcodl/PaperPlay/commit/17cf1e323792e5d9744a09f8593827e97ddd7c19))
- Rebuild the native libraries before a phone build ([`6e55c47`](https://github.com/maxcodl/PaperPlay/commit/6e55c470c1effab0a3e79fef144ae28cd1da2130))
- What is left after the audit ([`45df787`](https://github.com/maxcodl/PaperPlay/commit/45df7876b1b5eb69db4cbd0d2c58038b3d4c1a86))
- What the audit fixes cover and what is left ([`defa57e`](https://github.com/maxcodl/PaperPlay/commit/defa57e2b9c58fb9d2a0c23ee9543410993c310d))
- Audit checklist and rules ([`c11358b`](https://github.com/maxcodl/PaperPlay/commit/c11358bdc3b5f9f17843635a7d3816605ef6c2aa))

**Full changes:** [v1.21.3...v1.21.4](https://github.com/maxcodl/PaperPlay/compare/v1.21.3...v1.21.4)

## [1.21.3] - 2026-11-24

### Other changes
- Checklist: desktop memory test, seek and Home button ([`9b65294`](https://github.com/maxcodl/PaperPlay/commit/9b6529491c5c8d76558cda426e76787f32682234))
- Desktop: remove the window while hidden in the tray, reuse the running services on reopen ([`832f4f8`](https://github.com/maxcodl/PaperPlay/commit/832f4f85e0bd99a14aed485e9ab3bcdc67832d19))
- Desktop top bar: Home button without a background ([`8ce44ec`](https://github.com/maxcodl/PaperPlay/commit/8ce44ec4f2b6df57bb00ca36ebd15baf315b56b5))
- Bit-perfect seek: pause, seek, reopen the device, resume (no static) ([`1265fd6`](https://github.com/maxcodl/PaperPlay/commit/1265fd68afa9bceb0a1b1fe24e60c26cda1fd2e0))

### Maintenance
- Checklist catches up with merges, fixes and tests ([`021b823`](https://github.com/maxcodl/PaperPlay/commit/021b8230da85714426581fe41bffe157ee92ce02))

**Full changes:** [v1.21.2...v1.21.3](https://github.com/maxcodl/PaperPlay/compare/v1.21.2...v1.21.3)

## [1.21.2] - 2026-11-24

### Other changes
- Tests: bring four core tests in line with current behaviour ([`59191e4`](https://github.com/maxcodl/PaperPlay/commit/59191e4a963b84907237f2bef388027bd85e2dd9))
- Removed index chats sync to linked devices; no account reading without a login ([`d7db306`](https://github.com/maxcodl/PaperPlay/commit/d7db30604e1628e1ffdb6e670c294dceaafd3855))

**Full changes:** [v1.21.1...v1.21.2](https://github.com/maxcodl/PaperPlay/compare/v1.21.1...v1.21.2)

## [1.21.1] - 2026-11-24

### Other changes
- LAN address book: skip the pref write when nothing changed ([`2e0f074`](https://github.com/maxcodl/PaperPlay/commit/2e0f0744bcbba6637dfda068a079e2654ffebdf5))

**Full changes:** [v1.21.0...v1.21.1](https://github.com/maxcodl/PaperPlay/compare/v1.21.0...v1.21.1)

## [1.21.0] - 2026-11-24

### Added
- Add modern full-screen player UI with configurable backdrop blur ([`f2123c5`](https://github.com/maxcodl/PaperPlay/commit/f2123c50e8096aee8d8f58dbe52c86c1d0073e7a))

### Other changes
- Profile listening card: two columns on wide windows ([`30ca672`](https://github.com/maxcodl/PaperPlay/commit/30ca6727d666a3a8edd153d1bacd38aba60dceda))

**Full changes:** [v1.20.1...v1.21.0](https://github.com/maxcodl/PaperPlay/compare/v1.20.1...v1.21.0)

## [1.20.1] - 2026-11-24

### Other changes
- Playlist match: a radio edit tag after a dash matches the bracket forms ([`b17ddce`](https://github.com/maxcodl/PaperPlay/commit/b17ddcef498e8a1be01f08e183bb86efc502490b))
- Lyrics controls grouped on the left, slimmer chips ([`5e25164`](https://github.com/maxcodl/PaperPlay/commit/5e25164b76abacf2fdf790a81ca4c8e6900e6761))
- Profile stats row in the identity card, tighter listening card, themed seek bar option, Home next to Back, reopen output after fast seeks ([`4569f11`](https://github.com/maxcodl/PaperPlay/commit/4569f112385b4abbe6c6f6da5f6daa5a6557cb42))

### Maintenance
- Checklist note for downloadable player skins ([`63cd17d`](https://github.com/maxcodl/PaperPlay/commit/63cd17d3b4531ef31147b58d768cff90b26b0b60))

**Full changes:** [v1.20.0...v1.20.1](https://github.com/maxcodl/PaperPlay/compare/v1.20.0...v1.20.1)

## [1.20.0] - 2026-11-24

### Added
- Redesign lyrics view with full-screen support and multi-source pairing ([`2d65194`](https://github.com/maxcodl/PaperPlay/commit/2d6519436396ddfc816b9f14acb1468bf7daa7b9))

### Fixed
- Optimize usb audio device claiming, timeouts, and error handling policies ([`0caee5f`](https://github.com/maxcodl/PaperPlay/commit/0caee5fad6e69b6053a1590d0c608611ece1c51b))

### Other changes
- Profile listening dashboard with streak, heatmap, week, top of month; remove desktop top search box ([`56c92d4`](https://github.com/maxcodl/PaperPlay/commit/56c92d4c5b0983e40bf0e072d6187e5325f12e12))

### Maintenance
- Checklist for the Profile dashboard ([`965842a`](https://github.com/maxcodl/PaperPlay/commit/965842ada3c1e2251365b1319429d96d5f02417b))
- Checklist for search, settings search, auto copy and PR 15 ([`8220aa5`](https://github.com/maxcodl/PaperPlay/commit/8220aa5e32ad0f7d36092cb1d373ecda29b0f8df))

**Full changes:** [v1.19.0...v1.20.0](https://github.com/maxcodl/PaperPlay/compare/v1.19.0...v1.20.0)

## [1.19.0] - 2026-11-23

### Added
- Add UAC 1.0 composite DAC support and rate-setup hardening ([`9b52c14`](https://github.com/maxcodl/PaperPlay/commit/9b52c14aa861b0003016987d3699d7333d97419c))

**Full changes:** [v1.18.1...v1.19.0](https://github.com/maxcodl/PaperPlay/compare/v1.18.1...v1.19.0)

## [1.18.1] - 2026-11-23

### Fixed
- Copying songs from the index on its own is off until it is switched on ([`35774b4`](https://github.com/maxcodl/PaperPlay/commit/35774b469e58f3d57cd9a892b8847d7150d8db0e))

**Full changes:** [v1.18.0...v1.18.1](https://github.com/maxcodl/PaperPlay/compare/v1.18.0...v1.18.1)

## [1.18.0] - 2026-11-23

### Added
- A settings search result scrolls to its option and flashes it ([`8affbb0`](https://github.com/maxcodl/PaperPlay/commit/8affbb0296a7febc6362d334ca453747d52bd14d))

**Full changes:** [v1.17.0...v1.18.0](https://github.com/maxcodl/PaperPlay/compare/v1.17.0...v1.18.0)

## [1.17.0] - 2026-11-23

### Added
- Settings search also finds options inside pages ([`dc90f51`](https://github.com/maxcodl/PaperPlay/commit/dc90f5163a244871c22cd5bfbeb2b68c79ecf35e))

**Full changes:** [v1.16.0...v1.17.0](https://github.com/maxcodl/PaperPlay/compare/v1.16.0...v1.17.0)

## [1.16.0] - 2026-11-23

### Added
- Indexed songs without a saved cover show one read from Telegram, kept in memory only ([`4a83b89`](https://github.com/maxcodl/PaperPlay/commit/4a83b89e27cd37a2387e1b9f8af59b13f78de6d8))

### Fixed
- Search results stay on screen when the full player is closed ([`3df25df`](https://github.com/maxcodl/PaperPlay/commit/3df25dff5752505ae60ff5675ca6f5733d0a801d))
- The search text stays when the full player is closed ([`2c517a4`](https://github.com/maxcodl/PaperPlay/commit/2c517a4cc5af804979905905e95a87deb879c35d))

**Full changes:** [v1.15.0...v1.16.0](https://github.com/maxcodl/PaperPlay/compare/v1.15.0...v1.16.0)

## [1.15.0] - 2026-11-23

### Improved
- Less CPU while playing ([`a91ec3e`](https://github.com/maxcodl/PaperPlay/commit/a91ec3ecd2e9a88d4f6314d0c99de503e67ea09b))

### Added
- Play indexed songs without adding them, copy from the player, thumbnails and word search in the index ([`d72551e`](https://github.com/maxcodl/PaperPlay/commit/d72551ec04f8a6f27a18e95dab18d54583c0b198))
- Storage page shows what is on the device, shrink covers ([`05080d6`](https://github.com/maxcodl/PaperPlay/commit/05080d6c4c6b407487e5deb55050e8e9ac9465bd))
- 31-band parametric EQ, offline AutoEQ FTS5 DB, and Android full-screen EQ page ([`6ab15ca`](https://github.com/maxcodl/PaperPlay/commit/6ab15cab30daf540d836c2a54d5c37f95cf8b1da))
- Add screen-off ISO packet, jitter, scheduling, and power telemetry ([`4f6aae1`](https://github.com/maxcodl/PaperPlay/commit/4f6aae1fe583b169739a657f3a22c8a29e651609))

### Fixed
- Installer overwrites read-only files ([`4e8bcbb`](https://github.com/maxcodl/PaperPlay/commit/4e8bcbb1d985f563636ef9d48186440a02702b62))
- Restore the in-app change log page the About merge dropped ([`ba096da`](https://github.com/maxcodl/PaperPlay/commit/ba096dafea47e415e856382deeff7bcb95aba9a1))
- Persist and restore playback session state with position clamping ([`e46bf26`](https://github.com/maxcodl/PaperPlay/commit/e46bf26c446084540f9ffefe32280188c1d90d13))
- Format release notes and add in-app changelog page ([`0312f83`](https://github.com/maxcodl/PaperPlay/commit/0312f8313e75c5876fff4ac149b1986f4037d2d1))
- Stable release is not skipped when beta tagged the same commit first ([`8e2210a`](https://github.com/maxcodl/PaperPlay/commit/8e2210ab6e4ec72492c0d3a2fc702ab474edf86b))
- Desktop storage total measures only the app's folder ([`ff0fa35`](https://github.com/maxcodl/PaperPlay/commit/ff0fa3583950986704fb26e98b31013c2f08e9fe))
- Standby previous and next use the player's icons ([`11ab4f0`](https://github.com/maxcodl/PaperPlay/commit/11ab4f067b91db0458dfdfd0d016bd14418e49e1))
- Visualizer follows the music with the engine off ([`acbb021`](https://github.com/maxcodl/PaperPlay/commit/acbb021b1dbcde379b54e52674a8cf1fc0384367))
- Synced folders send songs added while the app runs ([`72b7431`](https://github.com/maxcodl/PaperPlay/commit/72b7431c9db9b57ad86478d41c941edbbc422606))
- Cache limit covers every Telegram store and actually frees space ([`11a7b15`](https://github.com/maxcodl/PaperPlay/commit/11a7b15a5e50182f9fabd6e5ab114fd39a133663))
- Harden screen-off scheduling, adaptive URB cushion, wakelocks, and soak harness ([`55dfdab`](https://github.com/maxcodl/PaperPlay/commit/55dfdab1732440848161992aa07ccc58ec3accfa))

### Maintenance
- Index preview and per-device bot reach in the checklist ([`297a9fe`](https://github.com/maxcodl/PaperPlay/commit/297a9fef15b8290c0b609302e836a89f3fea3cc1))
- Desktop test still to do ([`ee2e0b6`](https://github.com/maxcodl/PaperPlay/commit/ee2e0b6d996b9fade011e311f07e7bea0c846df0))
- Storage, battery, synced folders and visualizer ([`f45457e`](https://github.com/maxcodl/PaperPlay/commit/f45457e22dd3ca044ac5eee1e81fbe8fc31dd28f))

**Full changes:** [v1.14.1...v1.15.0](https://github.com/maxcodl/PaperPlay/compare/v1.14.1...v1.15.0)

## [1.14.1] - 2026-11-23

### Fixed
- The cover file check reads two columns and survives a read during a delete, which crashed the app ([`f997fad`](https://github.com/maxcodl/PaperPlay/commit/f997fadb826750181705669a2e3ee3ac82a50298))
- A duplicate delete batch that hits an error fails its posts and logs where, instead of crashing the app ([`b97eb75`](https://github.com/maxcodl/PaperPlay/commit/b97eb753ff8cfa419f5f184d20c674856a93e480))

### Other changes
- Delete: duplicate posts go at about 2 a second ([`b851de8`](https://github.com/maxcodl/PaperPlay/commit/b851de899233b984b306cd893d8bd9316b6d1f3b))

**Full changes:** [v1.14.0...v1.14.1](https://github.com/maxcodl/PaperPlay/compare/v1.14.0...v1.14.1)

## [1.14.0] - 2026-11-23

### Added
- Re-sending a song shows its download and upload progress and speed, and keeps the file until the upload ends; back arrow turns as a page opens ([`ac8206c`](https://github.com/maxcodl/PaperPlay/commit/ac8206cec687bb6e7a9be16b7c80fd4bafa77624))

### Fixed
- A refused copy says whether the chat restricts saving or what Telegram answered ([`9c2460e`](https://github.com/maxcodl/PaperPlay/commit/9c2460e0ee7616a47dd7c8c1047e394a32a8e355))
- A chat that blocks copying fails the rest of its songs at once; the copy shows why and logs an early stop ([`9e9d3d4`](https://github.com/maxcodl/PaperPlay/commit/9e9d3d4c52343e15fbb202a1f2d6dc6f87570a18))
- Copying from a chat that blocks it no longer downloads and re-uploads unless turned on ([`3bc246d`](https://github.com/maxcodl/PaperPlay/commit/3bc246d1595ab22ed29ea29b434661cf970dbce0))

**Full changes:** [v1.13.0...v1.14.0](https://github.com/maxcodl/PaperPlay/compare/v1.13.0...v1.14.0)

## [1.13.0] - 2026-11-23

### Improved
- Chat pages load from the index a page at a time; pause holds across restarts; posts keep their cover; chats keep their join links ([`47c3ca1`](https://github.com/maxcodl/PaperPlay/commit/47c3ca18d6b1a2a0a2aba151f7d8f75c1c00809c))

### Added
- Indexed chats in the library and search; copying runs as a task that can be paused and stopped ([`778d07b`](https://github.com/maxcodl/PaperPlay/commit/778d07b905ed807403d357c819e20619625b006d))
- Linked devices share library rows and the chat index; the PC reads for the phone; pause holds on both ([`c04905d`](https://github.com/maxcodl/PaperPlay/commit/c04905dc94d66402cabee607846a11d6517f14a0))
- Export and import the chat index as a file, with join links; an app backup imports too ([`ee9933f`](https://github.com/maxcodl/PaperPlay/commit/ee9933f15f8e7a4ba4917af06ab455471470c360))
- Backups carry the chat index and a restore never loses it; index stored with links, counts and library flags ([`5550a7d`](https://github.com/maxcodl/PaperPlay/commit/5550a7d77ff822c27fbf091ae82f8cd028ffec3d))
- Songs the bot can't reach show a red robot instead of being greyed out ([`d8a40ed`](https://github.com/maxcodl/PaperPlay/commit/d8a40edd5dfcd6293c6ca611bbf41f6e05848a0a))

### Fixed
- A deletion record from another device is not applied to songs still posted in the main chat ([`91e5c4d`](https://github.com/maxcodl/PaperPlay/commit/91e5c4d68cb1dc0d518359f9adc695c70d5e0b31))
- Songs whose post is gone from a fully read chat leave the library; a deletion whose post is still in the main chat no longer blocks sync ([`4de5b3e`](https://github.com/maxcodl/PaperPlay/commit/4de5b3e7c57b54779e136027865d1b000459af5b))
- Copying a song leaves the source post's caption behind ([`36e2cd3`](https://github.com/maxcodl/PaperPlay/commit/36e2cd31a9f782181a69f4b5fa1999bb8bf43873))
- Saving the index to Saved Messages no longer parses it back into memory ([`7a64f27`](https://github.com/maxcodl/PaperPlay/commit/7a64f27ca536ed24e6f7c5db767a5f38279c193a))
- Songs named Song - Artist get their artist back, checked after every scan ([`d822c16`](https://github.com/maxcodl/PaperPlay/commit/d822c16b69d4bc3ce7f5c55eccb8c22a3bc7c2ee))
- Readable update notes, buttons above them, device chips on their own row ([`0b22f1b`](https://github.com/maxcodl/PaperPlay/commit/0b22f1b6921525d30d82e6fba29c19d5a7b526f9))

**Full changes:** [v1.12.0...v1.13.0](https://github.com/maxcodl/PaperPlay/compare/v1.12.0...v1.13.0)

## [1.12.0] - 2026-11-22

### Added
- Storage page shows what is on the device, shrink covers ([`de2e981`](https://github.com/maxcodl/PaperPlay/commit/de2e981220fde0dcf534fb2803c5c032610e72be))

### Fixed
- Stable release is not skipped when beta tagged the same commit first ([`9944942`](https://github.com/maxcodl/PaperPlay/commit/9944942e78461b0ed337db9190a52e4aacc14e62))
- Desktop storage total measures only the app's folder ([`a131a6b`](https://github.com/maxcodl/PaperPlay/commit/a131a6b06aaddc62a719e3759118defaaa23db5f))
- Standby previous and next use the player's icons ([`56a5010`](https://github.com/maxcodl/PaperPlay/commit/56a5010f57d4d9ae2ecd83bae0416f0bf40cb545))
- Visualizer follows the music with the engine off ([`db44b7f`](https://github.com/maxcodl/PaperPlay/commit/db44b7f45c42a662ecfabee1bcd6ee4590565e58))
- Synced folders send songs added while the app runs ([`dcba616`](https://github.com/maxcodl/PaperPlay/commit/dcba6169cf46b6ade1dad4a6b67a812256449b9f))
- Cache limit covers every Telegram store and actually frees space ([`e970526`](https://github.com/maxcodl/PaperPlay/commit/e970526ad7ab7a3132dd6cf1a878ac6f09beb9dc))

### Improved
- Less CPU while playing ([`6e557df`](https://github.com/maxcodl/PaperPlay/commit/6e557df89b3b810882a7c6602bf79a4133c83404))

### Documentation
- Desktop test still to do ([`0abea9a`](https://github.com/maxcodl/PaperPlay/commit/0abea9a715f562641f75bb74016b8ca3c41262c7))
- Storage, battery, synced folders and visualizer ([`45687de`](https://github.com/maxcodl/PaperPlay/commit/45687de94e54bd3b1ddec7a8afd023e3e4f27a10))

**Full changes:** [v1.11.0...v1.12.0](https://github.com/maxcodl/PaperPlay/compare/v1.11.0...v1.12.0)

## [1.11.0] - 2026-11-22

### Added
- Add Aurora Wave style seekbar with live settings preview ([`77b1175`](https://github.com/maxcodl/PaperPlay/commit/77b1175737864569d5f9384d37964bcc43a24704))

### Fixed
- Update AuroraSeek behavior ([`2576771`](https://github.com/maxcodl/PaperPlay/commit/2576771db6d51bd91c2f40913f43752669e5a7d2))
- Add shutdown hook and graceful services cleanup on exit ([`7ecd60e`](https://github.com/maxcodl/PaperPlay/commit/7ecd60e4e24f7805608c10f5395264eac5cb43f7))
- Handle unshifted TDLib forum topic IDs and repair legacy data ([`160556a`](https://github.com/maxcodl/PaperPlay/commit/160556af824148a13155ea18c0669f0e01ebe2fa))
- Correct mouse back button mapping for Linux desktop X11 ([`95aca55`](https://github.com/maxcodl/PaperPlay/commit/95aca550124fa3a1f58d4fe6481cad98fc84730b))
- Dynamically strip foreign natives based on host OS ([`f2d8373`](https://github.com/maxcodl/PaperPlay/commit/f2d837315394928340e95218bc2148413ca49858))
- Implement safe usb interface claim lifecycle with tests ([`eb12d72`](https://github.com/maxcodl/PaperPlay/commit/eb12d72c03a5798f24c0d282a614df12d6229fd9))
- Prevent race conditions and invalid pointers in ring buffer clear and read operations ([`d3f5f41`](https://github.com/maxcodl/PaperPlay/commit/d3f5f412ad2a9354567c1ac124105b5a99ef20f3))
- Defer USB transfer deallocation until completion callback during active cancellation ([`0a937a3`](https://github.com/maxcodl/PaperPlay/commit/0a937a374f1311363a231b12a428b75f7167c47f))

**Full changes:** [v1.10.0...v1.11.0](https://github.com/maxcodl/PaperPlay/compare/v1.10.0...v1.11.0)

## [1.10.0] - 2026-11-22

### Added
- Harden USB bit-perfect session lifecycle and enable unified path ([`94bb91a`](https://github.com/maxcodl/PaperPlay/commit/94bb91a5d7a1387781905aa6e505e7f536ae8067))
- Add unified bit-perfect model, evaluator, prefs, and engine contracts ([`8fd32e5`](https://github.com/maxcodl/PaperPlay/commit/8fd32e53e28c179fd670e2cf7d4de3ac4a78b980))
- Add USB direct exclusive audio playback with UAC 2.0 support ([`b23877a`](https://github.com/maxcodl/PaperPlay/commit/b23877a1d46e6236da322f40e559c8d2daff99e8))
- Synced lyrics look with Sync pill, desktop top bar with profile menu, private session ([`c680477`](https://github.com/maxcodl/PaperPlay/commit/c68047784cf59fb5c52a0bb7e44fb91c44b03063))
- Send the queue to another device, Move, cleaner output pill ([`f2c2949`](https://github.com/maxcodl/PaperPlay/commit/f2c2949f1a8a788134c27414f4347bf77a61d710))
- Keep playing related songs when a list ends, landscape standby; fix seek static, device reconnect loop, recents at 30 seconds, visualizer ([`7cb05e6`](https://github.com/maxcodl/PaperPlay/commit/7cb05e66ac856bc5a888677405290b890d55a264))

### Documentation
- README, CHECKLIST and AGENTS for devices, autoplay, recents, lyrics, top bar ([`66ed999`](https://github.com/maxcodl/PaperPlay/commit/66ed99932199b9b2c078f15fa74b2d8f35bcec6a))

**Full changes:** [v1.9.12...v1.10.0](https://github.com/maxcodl/PaperPlay/compare/v1.9.12...v1.10.0)

## [Unreleased]

### Added
- Shared Bit-perfect architecture across Android and desktop: one unified `Bit-perfect` switch (off by default), `BitPerfectRouter`, verified-only `BitPerfectEvaluator`, exact 2^23 float32<->int24 round-trip and integer widening, speed bypass at non-1.0x, DoP hard-stop safety, and platform-isolated backup keys (`bit_perfect_mode.android` / `bit_perfect_mode.desktop`) with Android backup restore SharedPreferences re-sync
- Android: split standalone lazily-loaded `libusb_audio.so` (`engine/usb_audio/`, dynamically linked to LGPL `libusb-1.0.so`, 16 KB aligned) from pure DSP `libengine.so`; moved UAC 1.0/2.0 descriptor and topology resolution into Kotlin (`UsbDescriptorParser`, `UsbTopologyResolver`); added 25 s pause timeout release and immediate release on screen-off/route change/hot-unplug
- UI: unified `Bit-perfect` switch in Settings > Listening, Equalizer page/dialog (`BitPerfectRow`), and player bar (`BitPerfectButton`); renamed Android Settings > Listening subpage to `USB DAC` (hidden on desktop); one-time `vid:pid` USB discovery hint card; dev-gated `USB probe`
- Player: Screen-off and Doze CPU wakelock via Media3 `C.WAKE_MODE_LOCAL` and in-memory diagnostic ring log (`UsbRingLog`) with `PHASE0_SUMMARY` export

## [1.9.12] - 2026-11-19

### Documentation
- Session status, covers rules, handover rule ([`2d45f7a`](https://github.com/maxcodl/PaperPlay/commit/2d45f7a1de6b3a1b7197afa028de717097d314a9))

### Other changes
- Mixes: build Home mixes from the recommender (sound groups, right now, new to you, ordered to flow) and remove the old mood mixer ([`c191557`](https://github.com/maxcodl/PaperPlay/commit/c191557623dc3123edc37149271b1511cd4508eb))
- Covers: remove cover files no song uses any more ([`fd53759`](https://github.com/maxcodl/PaperPlay/commit/fd53759877d24347de46554f798c296b4bfd7e5d))
- Recs: log every listen with how much was heard, and a recommender that learns from them ([`6a182d5`](https://github.com/maxcodl/PaperPlay/commit/6a182d57398cb609067b405e914fa542722de2d5))
- Covers: saved at display size, one shared file per picture, existing covers packed once in the background ([`1a3757e`](https://github.com/maxcodl/PaperPlay/commit/1a3757eae9c82c218cf731cc42b85ad9b20491e4))
- Recs: measure each song's sound (tempo, key, loudness, timbre) in the Rust engine on the phone ([`eeb75b7`](https://github.com/maxcodl/PaperPlay/commit/eeb75b7cdc4a62f2b8aa31acf779b8657ae0abb1))
- Cache: limit and clear also cover the account's and extra bots' downloads and half-finished files ([`7847eb4`](https://github.com/maxcodl/PaperPlay/commit/7847eb4958a9e466316ee2ef03a1961255cd00b5))
- Desktop: stereo width and crossfeed in the mpv engine, shown on the PC equalizer page ([`d0234fd`](https://github.com/maxcodl/PaperPlay/commit/d0234fd37dab3ec5c12872ecc11c8bd266c492a1))
- Lyrics: closest-length timed version first, choose the lyrics writing ([`64a6abe`](https://github.com/maxcodl/PaperPlay/commit/64a6abe28e5cb923ad64e59cd2c230046085a463))
- Settings: keep running in the background switch on desktop ([`194b81a`](https://github.com/maxcodl/PaperPlay/commit/194b81a43fe708e93cb4b164940d85e5511c1c16))
- Desktop: option to quit on close instead of the tray; upload skip matches names ignoring case and logs why ([`6e801dc`](https://github.com/maxcodl/PaperPlay/commit/6e801dcad6f1362cf369934ac293ea352c830363))
- Search: 'title by artist' finds the song ([`d90f6e6`](https://github.com/maxcodl/PaperPlay/commit/d90f6e63d3461e834a97d704e06fefca533c0d2f))
- Mark a song as recently played after 5 seconds, not when it stops ([`702ad01`](https://github.com/maxcodl/PaperPlay/commit/702ad013e4f1199ed61aed54750415c2d29145a2))
- Desktop: Listening bit-perfect row is the same switch as the equalizer dialog's ([`67fdb40`](https://github.com/maxcodl/PaperPlay/commit/67fdb40258ec0d62c86e3d0a1dfb93b353bd34bd))

**Full changes:** [v1.9.11...v1.9.12](https://github.com/maxcodl/PaperPlay/compare/v1.9.11...v1.9.12)

## [1.9.11] - 2026-11-19

### Other changes
- Ui: nicer toasts and desktop placement, solid heart by the song name and in Made by, main bot label ([`31e5639`](https://github.com/maxcodl/PaperPlay/commit/31e5639c665f6745ae91ee643dc86fe1c62251f7))
- Desktop: folder picker returns the path through a UTF-8 file and logs how the dialog ended ([`e36bb53`](https://github.com/maxcodl/PaperPlay/commit/e36bb534d9daac6792df8803996e6f9d8ff5f0ae))

**Full changes:** [v1.9.10...v1.9.11](https://github.com/maxcodl/PaperPlay/compare/v1.9.10...v1.9.11)

## [1.9.10] - 2026-11-19

### Other changes
- Ui: cover outline in pure black or white, card radius matches cover radius plus padding ([`549d452`](https://github.com/maxcodl/PaperPlay/commit/549d452f0b5596342a2db0814efcd9a64d443eb2))
- Cache: clearing the cache also clears audio the own account downloaded ([`09667b6`](https://github.com/maxcodl/PaperPlay/commit/09667b663b53a81c83abb2ee4ee99af11af39a8a))

**Full changes:** [v1.9.9...v1.9.10](https://github.com/maxcodl/PaperPlay/compare/v1.9.9...v1.9.10)

## [1.9.9] - 2026-11-19

### Other changes
- Desktop: folder picker logs why the Windows dialog failed and falls back to Java's chooser ([`8ed27cf`](https://github.com/maxcodl/PaperPlay/commit/8ed27cf2b585379d9b8471d9d6df9c12de0009fb))
- Ui: guard two more list keys against repeats ([`f8b0488`](https://github.com/maxcodl/PaperPlay/commit/f8b0488b5b3c7fc6925f7d27b006a32137f3dfb4))
- Scan: the account scan of the main chat now does a full read so missing songs are added and gone ones pruned ([`3bd8b2c`](https://github.com/maxcodl/PaperPlay/commit/3bd8b2c19839c6b75370fb9dceb9a59637f0e68a))
- Duplicates: one row per post, random tile covers, connecting notice once per run ([`541df9b`](https://github.com/maxcodl/PaperPlay/commit/541df9b1d760214d462c2864d2f60cfc50fe9aeb))
- Duplicates: unique list keys per group, fixes crash when a post is in two groups ([`c35026b`](https://github.com/maxcodl/PaperPlay/commit/c35026b670d1e3ad6ab2ff140f1b1556569980b7))

**Full changes:** [v1.9.8...v1.9.9](https://github.com/maxcodl/PaperPlay/compare/v1.9.8...v1.9.9)

## [1.9.8] - 2026-11-18

### Other changes
- Checklist: settings pages and stray songs ([`3bf3272`](https://github.com/maxcodl/PaperPlay/commit/3bf32729b91de19bd5a2594f1bf05ebb8eb08d3b))
- Settings: rows keep icons and trailing content, Library and Telegram pages in cards, Clear deleted songs ([`803183b`](https://github.com/maxcodl/PaperPlay/commit/803183b241d818742233980c4a247aef271c274d))
- Backend: clear deleted songs, clearer message when nothing needs copying ([`7b1c72e`](https://github.com/maxcodl/PaperPlay/commit/7b1c72e0471924c4f09c3a814ec9b1be6349fb4f))
- Index: copy posts again that no bot can read, clear library-only songs whose post was deleted ([`1607537`](https://github.com/maxcodl/PaperPlay/commit/16075379ff81b9c22c80920682f6d23c81fbfd55))
- Readme: chat index, copying and songs the bot can't read ([`30450bd`](https://github.com/maxcodl/PaperPlay/commit/30450bdde814aa5beefbfd25a66ab182b3e8dc55))
- Checklist: chat index and copying ([`847ac13`](https://github.com/maxcodl/PaperPlay/commit/847ac134de29ed53459c1f9e21162cb1a09154e7))
- Library: copy picked songs to the chat, select songs the bot can't read ([`023dcbd`](https://github.com/maxcodl/PaperPlay/commit/023dcbdcf17ffb1c368521835992e382af01adac))
- Chats page: details, open and remove, pause and resume, copy speed, background indexing, + for Spotify matches ([`2be241f`](https://github.com/maxcodl/PaperPlay/commit/2be241f3453552dfe9baf8dbfc87f61e9f941d4e))
- Index: resumes stopped reads, matches the whole library, copies into the main chat with a fallback, library-only songs move to their post ([`986161f`](https://github.com/maxcodl/PaperPlay/commit/986161f60601ba26112b69924c99a5a267654762))
- Notifications: the first running task is the service notification, no standing card, service stops 20 s after work ([`d72c820`](https://github.com/maxcodl/PaperPlay/commit/d72c820bd3b1afd273baf86928c988dc05c81043))
- Checklist: uploads, names and the desktop layout ([`7ab5616`](https://github.com/maxcodl/PaperPlay/commit/7ab56168edbd128e8088ea234235ecd528483a63))
- Desktop: the now playing view keeps the chosen background instead of a cover colour wash ([`83241f3`](https://github.com/maxcodl/PaperPlay/commit/83241f37244bb8960252f65b840acadba2a5ce74))
- Desktop: room for the now playing panel is kept from the first frame so the page does not re-lay out ([`756bd7b`](https://github.com/maxcodl/PaperPlay/commit/756bd7b8526fc9b5114754af531be6ccb55162e6))

**Full changes:** [v1.9.7...v1.9.8](https://github.com/maxcodl/PaperPlay/compare/v1.9.7...v1.9.8)

## [1.9.7] - 2026-11-18

### Fixed
- Adjust bitmap size and update blur handling in CoverBlurLayer ([`d71007c`](https://github.com/maxcodl/PaperPlay/commit/d71007ca4afa8d28f14e212e9963a5e957d79d4b))

**Full changes:** [v1.9.6...v1.9.7](https://github.com/maxcodl/PaperPlay/compare/v1.9.6...v1.9.7)

## [1.9.6] - 2026-11-18

### Other changes
- Upload: title and artist come from the file's own tags; the sending bot owns the new song ([`80aeb0b`](https://github.com/maxcodl/PaperPlay/commit/80aeb0b7b4c2f86b429b5141a78c1173f5b4c742))
- Names: Song - Artist file names are swapped back using the artists the library already knows ([`64ca4b4`](https://github.com/maxcodl/PaperPlay/commit/64ca4b4a3fc43a43bb7441eb39aa096cd4fc4d6e))
- Agents: audio engine layout, tests, clicks, headroom and the path for a new setting ([`16d573f`](https://github.com/maxcodl/PaperPlay/commit/16d573f5fb2a42143d58048b383d5a97b2bdeaf1))
- Engine: settings per output, dynamic bass, de-esser and crossfeed; checklist ([`7491b9d`](https://github.com/maxcodl/PaperPlay/commit/7491b9d0452db7f1539d0ebaacbab7fcd80ea90a))
- Agents: rules for wrong tags and checking real data ([`16b39e0`](https://github.com/maxcodl/PaperPlay/commit/16b39e0ae4d451ac96027b69444d400f2a034f84))
- Agents: measure speed claims, phone and Telegram test rules, line endings, stop builds you started ([`a5a65fa`](https://github.com/maxcodl/PaperPlay/commit/a5a65fa89b330e04f93e39e353dfad573ec1cb60))
- Readme: Home animation setting, old posts need the account to delete ([`a456659`](https://github.com/maxcodl/PaperPlay/commit/a4566599ea47da5a87bbc9169b17353d99c6b72f))
- Agents: compile after install, bots delete only recent posts, composition and animation rules ([`185b40d`](https://github.com/maxcodl/PaperPlay/commit/185b40d1e1325b2d6f95f6497cc70b3173797ef8))
- Checklist: deletes and duplicates, start-up and Home, notifications (18 Nov) ([`40d187c`](https://github.com/maxcodl/PaperPlay/commit/40d187cd6805b8c62a42722fc9b0ce510f838900))
- Checklist: swapped names and the blank notification ([`4981d7f`](https://github.com/maxcodl/PaperPlay/commit/4981d7f240359a2a8239a20ef772c164c5b446c8))
- Engine: earphone correction (AutoEq parametric) on the phone, engine extras in the player equalizer ([`59c404a`](https://github.com/maxcodl/PaperPlay/commit/59c404a69c88927741d0e96e178a82a7f1e5ae51))
- Engine: bass keeps its rumble with less boom, stereo width above the bass, clearer bass and vocal presets ([`c8669da`](https://github.com/maxcodl/PaperPlay/commit/c8669da8611824f132e5b26b77087b02ed744f39))
- Engine: smooth changes, true-peak ceiling, held bass limiter, exact level mode, level-matched A/B ([`af1374e`](https://github.com/maxcodl/PaperPlay/commit/af1374e95f51416ed4e66b387f9ac02ac7e7ce02))
- Notifications: the service's own notification no longer counts running tasks ([`59213a7`](https://github.com/maxcodl/PaperPlay/commit/59213a79c8d723ff3ed298b8688fa373b92e5b5b))
- Media notification: posted ungrouped so the shade does not draw it as an empty card ([`6e7eb06`](https://github.com/maxcodl/PaperPlay/commit/6e7eb06597690517c1557edc8e0ef665af0d4c4d))
- Home animation: no tilt (it re-uploaded every cover each frame) and fade per piece ([`bc557cb`](https://github.com/maxcodl/PaperPlay/commit/bc557cb63e9322fecfba486b3ec6d315546e93bd))
- Home: waits for its data before animating in, no spinner at start, second background deferred; setting to turn the home animation off ([`330a4d4`](https://github.com/maxcodl/PaperPlay/commit/330a4d43180c87a34c70dbb1fc0731d4b786e692))
- Home: no placeholders, the animation waits for the first frames; the saved page loads beside the backend with one query ([`5af36f1`](https://github.com/maxcodl/PaperPlay/commit/5af36f1332bad5496bbb52f02895b9ac2fea6af5))
- Names: swapped title and artist tags are fixed, repair runs again ([`2cc4e2d`](https://github.com/maxcodl/PaperPlay/commit/2cc4e2d2f29672579f20fa7b69eee91e6ea86889))
- Home: placeholders leave at once when the fly-in starts; the first covers no longer wait for the busy main thread ([`4373f9e`](https://github.com/maxcodl/PaperPlay/commit/4373f9e81a7433901513b2ec28e1f4e0bc624db5))
- Home: wide windows get fixed-width tiles beside a compact recently played row; covers are scaled to the asked size and pre-uploaded off the main thread ([`e4d48d2`](https://github.com/maxcodl/PaperPlay/commit/e4d48d20689c77e5981843543f5858438fc96c6a))
- Home: last launch's page is drawn at once with its covers; songs, albums and artists are built only when shown; tiles and cards fly in at start ([`e2e2275`](https://github.com/maxcodl/PaperPlay/commit/e2e227562236d332cd6b187b37fd329ee1d91043))
- Home: the plan no longer waits for the whole library or restarts for weather and taste settings ([`8c1b3db`](https://github.com/maxcodl/PaperPlay/commit/8c1b3dbe7e325aebfed5fecd49f18887a21c929c))
- Startup: home plan no longer restarts when the scan or covers begin; warm the library and home flows early; update: skip saves the release shown ([`60e9259`](https://github.com/maxcodl/PaperPlay/commit/60e92591d17f3f10309f3ca409f8a9923a5be15d))
- Home: topic lists built off the main thread, cover queue no longer redraws the shell; duplicates: notice for posts only the account can delete ([`f8df3d6`](https://github.com/maxcodl/PaperPlay/commit/f8df3d6898dda6e704ab4388885571582d735f02))
- Update: download has timeouts and retries a connect timeout; desktop no longer caches the first dead GitHub address ([`59b2081`](https://github.com/maxcodl/PaperPlay/commit/59b2081b90fac54378ec2e96dfb55f1cab1a7ca2))

**Full changes:** [v1.9.5...v1.9.6](https://github.com/maxcodl/PaperPlay/compare/v1.9.5...v1.9.6)

## [1.9.5] - 2026-11-17

### Improved
- Keyed shelves and queue, idle polling gated, no right-click handler on phone ([`aacd1f7`](https://github.com/maxcodl/PaperPlay/commit/aacd1f756faf9e1ace056d214309c6a09586b914))

### Other changes
- Delete: posts older than 48 hours are not tried through bots; the error says to log in the account ([`687eff2`](https://github.com/maxcodl/PaperPlay/commit/687eff265eb293db240c32789208e94a71c1aec8))
- Ignore the local secrets folder ([`a3c293e`](https://github.com/maxcodl/PaperPlay/commit/a3c293efe9e059957b82a371b8ccd86814d524ed))
- Notifications: the activity line is not shown when it repeats another task ([`2e90a70`](https://github.com/maxcodl/PaperPlay/commit/2e90a703d4301e4802619957efbb958cede8536d))
- Glass: nav bar blurs the page colour too; duplicates: bot names, no stray @, refresh drops posts every bot cannot see ([`f10ade3`](https://github.com/maxcodl/PaperPlay/commit/f10ade395e694be2d4bc1e51414785c4c0722d0c))
- Duplicates: each post shows the bot the library holds it under, and the delete log says which bot was tried for each post ([`87d65cb`](https://github.com/maxcodl/PaperPlay/commit/87d65cb8091f70d9418afbbbb461d93adffcd6f9))
- Duplicates: the post text shares the row so the menu button is never pushed off ([`0499d93`](https://github.com/maxcodl/PaperPlay/commit/0499d937e915fb7518d67023519a552603ec0060))
- Delete: posts every bot says are not found are treated as gone; duplicates page rows get a menu to open the post in Telegram ([`f91235d`](https://github.com/maxcodl/PaperPlay/commit/f91235da6cd8fe6bf7071884d63b3e113b42deb6))
- Delete: the owning bot deletes its own posts, keeper check only with the account logged in, rights diagnosed in the log; Tasks row counts running tasks ([`2d996bb`](https://github.com/maxcodl/PaperPlay/commit/2d996bb3261d3a92fe444fb4e1883d8abd3f30c5))
- Names: split Song - Version - Artist files correctly at upload and scan, and repair the songs already split wrong ([`0d978f3`](https://github.com/maxcodl/PaperPlay/commit/0d978f3dc2d275e8c645f243c84a8ac1ee359690))
- Notifications: each running task is its own notification with its own bar; library list rebuild rate-limited; Home sections ease in; upload buttons ([`1953925`](https://github.com/maxcodl/PaperPlay/commit/19539251884d25456e6958c6247d579d259ef35c))
- Delete: extra bots are judged by Telegram's own answer per post, not by a failed fetch; notification also shows deleting and updates faster ([`4e7e97e`](https://github.com/maxcodl/PaperPlay/commit/4e7e97eb57743467ec250f8e6b033b8037d88f35))
- Selection bar: play, playlist and favorite as icons so the count fits ([`11e5fb6`](https://github.com/maxcodl/PaperPlay/commit/11e5fb6d643d25f41b0298d21b0e8a7b8fd5a085))
- Uploads: speed, totals and time left, percent per file, and an Upload entry on Profile ([`fb8138f`](https://github.com/maxcodl/PaperPlay/commit/fb8138f747d209f9ac2022e2d6c472c0ce72e553))
- Selection bar can delete songs from Telegram; duplicates buttons wrap instead of squashing ([`01b1e84`](https://github.com/maxcodl/PaperPlay/commit/01b1e84bf431b493e26229732cbc131e770c8493))
- Delete: five posts per call so progress moves in small steps ([`da8b02d`](https://github.com/maxcodl/PaperPlay/commit/da8b02dfbbdcce4ca3430af3fe5f1ece1356da93))
- Duplicates: wider re-upload size match and a tick all but the best button ([`753c98b`](https://github.com/maxcodl/PaperPlay/commit/753c98b83a9a0bed79c4bb6eb79dbf79bfa66c96))
- Delete: extra bots take the posts the account and main bot could not, and the error names Telegram's reason ([`988ea34`](https://github.com/maxcodl/PaperPlay/commit/988ea34fd3101e3b2b3bb9e43674cf48e497c16c))
- Filter chip for songs the bot can't reach is always shown, with a count ([`145ba15`](https://github.com/maxcodl/PaperPlay/commit/145ba154b22f4aa8f43701b3600f50e27b316fd4))
- Start-up: Home waits for its lead covers, any-size cover shown while the exact one decodes, softer cover fade ([`42209a5`](https://github.com/maxcodl/PaperPlay/commit/42209a5ad17bfa9f6af53c27e34c2cbd95f28ab8))
- Songs only an account can read are greyed with a warning and can be filtered ([`e533c1c`](https://github.com/maxcodl/PaperPlay/commit/e533c1cd0798ec11ba97301c72206cb0ca1ce128))
- Update: find Shizuku builds with a suffixed package id ([`f59c692`](https://github.com/maxcodl/PaperPlay/commit/f59c69231b0f77df68e091512021e6da979c0833))

**Full changes:** [v1.9.4...v1.9.5](https://github.com/maxcodl/PaperPlay/compare/v1.9.4...v1.9.5)

## [1.9.4] - 2026-11-17

### Documentation
- Checklist for account songs, bit-perfect, details popup, standby, delete notice ([`675becf`](https://github.com/maxcodl/PaperPlay/commit/675becf28ae62130b87cd3811945f7dda5102667))

### Other changes
- Ui: equalizer shows a fader board, true audio a waveform ([`a0b9f8e`](https://github.com/maxcodl/PaperPlay/commit/a0b9f8e59e55c86770617e8372bdf83c5e9eea59))

**Full changes:** [v1.9.3...v1.9.4](https://github.com/maxcodl/PaperPlay/compare/v1.9.3...v1.9.4)

## [1.9.3] - 2026-11-17

### Other changes
- Scan: an extra bot takes over the songs saved as account songs when it can read their posts ([`24df215`](https://github.com/maxcodl/PaperPlay/commit/24df215840c8aa1a8aec9485d6cd33a9aa03ad1b))

**Full changes:** [v1.9.2...v1.9.3](https://github.com/maxcodl/PaperPlay/compare/v1.9.2...v1.9.3)

## [1.9.2] - 2026-11-17

### Other changes
- Streaming: remember which bot found an account song so later plays and covers go straight to it ([`225adcb`](https://github.com/maxcodl/PaperPlay/commit/225adcb727884b71af5811fcbe5a1fefc1b937a1))
- Player: stream errors answer the player and are logged, mpv skips its youtube-dl hook ([`a5ed339`](https://github.com/maxcodl/PaperPlay/commit/a5ed3390c6110ddae2012791d3bd14d2bf2191f6))
- Streaming: songs added through an account play through the bots when the account is gone ([`edd3bc5`](https://github.com/maxcodl/PaperPlay/commit/edd3bc541a323580856c1f1015237db51ef06fef))
- Standby: always release keep-screen-on, even if closing the dialog window fails ([`201be1b`](https://github.com/maxcodl/PaperPlay/commit/201be1b37c03dbf7743e426c5a77e8746715445a))

**Full changes:** [v1.9.1...v1.9.2](https://github.com/maxcodl/PaperPlay/compare/v1.9.1...v1.9.2)

## [1.9.1] - 2026-11-17

### Other changes
- Ui: Top bars look and the Dot and Text selection looks are wired; checklist ([`c9ac84f`](https://github.com/maxcodl/PaperPlay/commit/c9ac84f5692b54e17235b82d43807802bf1cb56a))
- Ui: player bar background is transparent, card or glass ([`50957af`](https://github.com/maxcodl/PaperPlay/commit/50957afe9a9914f0cc0a3cba85b6c1eb2d0d82fc))
- Ui: glass settings (edge, shadow, glow, saturation) apply to every glass surface ([`f0982e9`](https://github.com/maxcodl/PaperPlay/commit/f0982e928f63d0bed00ad262d400bd874404bb9d))
- Delete: say when copies stay in other chats and log which posts went ([`85dbc45`](https://github.com/maxcodl/PaperPlay/commit/85dbc45d3d44f4b722ed2b5c8e5273f2514cb115))
- Ui: keyboard shortcuts stay off while a text box holds focus ([`b923a48`](https://github.com/maxcodl/PaperPlay/commit/b923a483d05c829b1b4efa9adb859281cd2bb2ff))
- Ui: separate corner size for panels, cards, covers, chips and dialogs; the bit-perfect row matches the equalizer row ([`0c88c8c`](https://github.com/maxcodl/PaperPlay/commit/0c88c8ce4f0ff2d50977808f1d1bd66606f06902))
- Ui: Settings switch for the taskbar buttons ([`fab179e`](https://github.com/maxcodl/PaperPlay/commit/fab179e463d8bde5d001a0be1cb6563939456f19))
- Desktop: previous, play or pause and next buttons under the taskbar preview ([`b1111c1`](https://github.com/maxcodl/PaperPlay/commit/b1111c119511f57a026a5210029fe2b14827efed))
- Ui: the bar shows the sound status while Now playing is open ([`2408336`](https://github.com/maxcodl/PaperPlay/commit/240833647e16d6b442a3bc953b3ba14f18324db4))
- Player: mpv output reloads itself after under-runs and when the song's format changes, and logs what it opened ([`ee38aa6`](https://github.com/maxcodl/PaperPlay/commit/ee38aa600254a5454ecebde4d1c44e1e737cbe06))
- Ui: toggles use a contrast-aware on colour, equalizer bars icon, animated true-audio gem button ([`13fe78b`](https://github.com/maxcodl/PaperPlay/commit/13fe78bc2e95aae8b0e13a2e38d589b1a4e85fd9))

**Full changes:** [v1.9.0...v1.9.1](https://github.com/maxcodl/PaperPlay/compare/v1.9.0...v1.9.1)

## [1.8.11] - 2026-11-17

### Other changes
- Player: bit-perfect opens the device at each song's own rate and takes exclusive output again on every new song ([`1b63230`](https://github.com/maxcodl/PaperPlay/commit/1b63230c59ec35b28b1c4a97d613f7d6fc1541d3))
- Ui: toggle buttons show a fill when on ([`f2df8cb`](https://github.com/maxcodl/PaperPlay/commit/f2df8cb0644be4459c1e9c5a282913d9642b850e))
- Ui: smaller logo and version text in the Profile About row ([`2dddafb`](https://github.com/maxcodl/PaperPlay/commit/2dddafb14d3433bcdd16652b8a8607c5c93edb77))

**Full changes:** [v1.8.10...v1.8.11](https://github.com/maxcodl/PaperPlay/compare/v1.8.10...v1.8.11)

## [1.8.10] - 2026-11-17

### Documentation
- Sidebar lists fold like Tools ([`b93a7c5`](https://github.com/maxcodl/PaperPlay/commit/b93a7c530e3317cbc635805415c75b3bf5858880))

### Other changes
- Ui: Playlists and From Telegram fold like Tools in the PC sidebar ([`4d6d515`](https://github.com/maxcodl/PaperPlay/commit/4d6d515571d37ec281dd23b754ae5943096d4318))
- Player: mpv warnings go to the activity log ([`e882046`](https://github.com/maxcodl/PaperPlay/commit/e8820468fb016e81558ad16444827e013a475d65))

**Full changes:** [v1.8.9...v1.8.10](https://github.com/maxcodl/PaperPlay/compare/v1.8.9...v1.8.10)

## [1.8.9] - 2026-11-17

### Other changes
- Ui: the PC bar leaves out transport while Now playing is open, bit-perfect gets its own icon ([`9714674`](https://github.com/maxcodl/PaperPlay/commit/97146740f261690f83fe66e31927724d258f359f))
- Sync: a playlist change reaches linked devices within seconds ([`3ff3d8b`](https://github.com/maxcodl/PaperPlay/commit/3ff3d8b3ff0294b5468df21699ec23456712d1a9))
- Installer: end the app without its child processes so the in-app updater's setup survives ([`066a423`](https://github.com/maxcodl/PaperPlay/commit/066a42325f81ed45d63d2f00a36aedf1e127ede5))
- Ui: smaller playlist cards on Home so more show in the sideways row ([`6635ff0`](https://github.com/maxcodl/PaperPlay/commit/6635ff0f50ddfe7398d73c5aee2ca24a07a2d639))

**Full changes:** [v1.8.8...v1.8.9](https://github.com/maxcodl/PaperPlay/compare/v1.8.8...v1.8.9)

## [1.8.8] - 2026-11-17

### Other changes
- Ui: one details popup for the song and its sound ([`a1ac296`](https://github.com/maxcodl/PaperPlay/commit/a1ac296dca237823d92305fc05111edf6e7fadfd))
- Ui: bit-perfect button in the PC player bar ([`d61d03a`](https://github.com/maxcodl/PaperPlay/commit/d61d03a113b75e1f0f97cc549fa25a5dfa77a991))
- Player: mpv engine gives back exclusive output while paused and takes it again on play ([`2fcfdd7`](https://github.com/maxcodl/PaperPlay/commit/2fcfdd77ebf494f48dad8e95dfea683b59636f1b))
- Memory: trim idle pages when the PC window is hidden, free decoded covers when the phone app is in the background ([`c051b1f`](https://github.com/maxcodl/PaperPlay/commit/c051b1f2ba025ed29935cbd1dd1abed9c3ef1618))
- Ui, core: a picked cover is shrunk once when saved ([`e396023`](https://github.com/maxcodl/PaperPlay/commit/e3960236ad55520ebc4914aff78c5cd8568f9399))
- Ui: the page under the full player is not composed while the player covers it ([`31e93be`](https://github.com/maxcodl/PaperPlay/commit/31e93be57991e04efd74e1bef6abef07d3f137c8))
- Ui: Home keeps recently played on top and folds the other shelves into one row of cards ([`e51aba4`](https://github.com/maxcodl/PaperPlay/commit/e51aba44e4a5b6d9d7884e30f6c3fcbd384ef82f))
- Installer: end the tray-hidden app before replacing files ([`9a8560f`](https://github.com/maxcodl/PaperPlay/commit/9a8560fdf236e36642e03ae684e1b85c59311077))

**Full changes:** [v1.8.7...v1.8.8](https://github.com/maxcodl/PaperPlay/compare/v1.8.7...v1.8.8)

## [1.8.7] - 2026-11-17

### Other changes
- Ui, player: bit-perfect mode on the PC, bass gives back some level, Output info from the player bar ([`f1486e6`](https://github.com/maxcodl/PaperPlay/commit/f1486e6a37eaad3f2c4b2368ddd7465360758f8d))

**Full changes:** [v1.8.6...v1.8.7](https://github.com/maxcodl/PaperPlay/compare/v1.8.6...v1.8.7)

## [1.8.6] - 2026-11-17

### Other changes
- Ui: Bass dial on the PC with the mpv engine and an Equalizer button in the player bar ([`c909213`](https://github.com/maxcodl/PaperPlay/commit/c909213f3c7c6bafa6c418eeb155f090d79c4d6e))
- Ui: playing song and queue pick up a changed cover at once ([`ac2aa15`](https://github.com/maxcodl/PaperPlay/commit/ac2aa15e4a72a10a3a11dbd29d652362ed356e47))
- Player: mpv engine remembers a seek made before the song loads ([`6b1fef4`](https://github.com/maxcodl/PaperPlay/commit/6b1fef4290ee0d14fca275a039f3bf6f6a351235))

**Full changes:** [v1.8.5...v1.8.6](https://github.com/maxcodl/PaperPlay/compare/v1.8.5...v1.8.6)

## [1.8.5] - 2026-11-17

### Documentation
- Mpv engine notes and checklist ([`20a15d1`](https://github.com/maxcodl/PaperPlay/commit/20a15d1f4dc7393e08227471f042fe331fd48b65))

### Other changes
- Player: mpv output info reads the real exclusive setting and names the default device ([`0d62b75`](https://github.com/maxcodl/PaperPlay/commit/0d62b758316b1c82014131ccc68f758e94d5ec85))
- Ui: PC settings for the mpv engine, exclusive output and correction profile ([`d915b89`](https://github.com/maxcodl/PaperPlay/commit/d915b89a27c6e2d0f449a12d7f48a1f2ed9b897c))
- Player: mpv engine for the desktop with equalizer, bass, profiles and exclusive output ([`473e388`](https://github.com/maxcodl/PaperPlay/commit/473e3880d9df2c6186dc2087cd285c1882157b1c))

**Full changes:** [v1.8.4...v1.8.5](https://github.com/maxcodl/PaperPlay/compare/v1.8.4...v1.8.5)

## [1.8.4] - 2026-11-16

### Documentation
- Audio engine rules and checklist ([`4a15dd4`](https://github.com/maxcodl/PaperPlay/commit/4a15dd4bea7ac3477afa122868d729df71e597e9))

### Other changes
- Ui: equalizer in the player menu, bass slider, earphone presets, engine rows in output info ([`5356454`](https://github.com/maxcodl/PaperPlay/commit/53564548c2f2e469e6d7dd9bdc2b59cf74c91bc4))
- Player: run the engine equalizer and bass in the Android audio path ([`d63107e`](https://github.com/maxcodl/PaperPlay/commit/d63107e79a3eec3ef10f74fcc0a98b48cb46b0a7))
- Engine: Rust equalizer, bass and limiter library ([`faee885`](https://github.com/maxcodl/PaperPlay/commit/faee8850b5229e724f3f5f581d5f9e6ce01f5b91))

**Full changes:** [v1.8.3...v1.8.4](https://github.com/maxcodl/PaperPlay/compare/v1.8.3...v1.8.4)

## [1.8.3] - 2026-11-16

### Fixed
- Remove the stray space from the repository URLs after the rename ([`c91d9cf`](https://github.com/maxcodl/PaperPlay/commit/c91d9cf52f105fa696427d113d23eb34f7a0434c))

**Full changes:** [v1.8.2...v1.8.3](https://github.com/maxcodl/PaperPlay/compare/v1.8.2...v1.8.3)

## [1.8.2] - 2026-11-16

### Other changes
- Playback: picking from the queue keeps its order (shuffle no longer reshuffles it) and rewind goes back to the song played before ([`0912b8c`](https://github.com/maxcodl/PaperPlay/commit/0912b8cce0976c0ccfbe973a56a4eb88e2745bed))

**Full changes:** [v1.8.1...v1.8.2](https://github.com/maxcodl/PaperPlay/compare/v1.8.1...v1.8.2)

## [1.8.1] - 2026-11-16

### Other changes
- Desktop player: shorter input buffer so a song starts sooner, and the log says codec, rate and start delay ([`89b7692`](https://github.com/maxcodl/PaperPlay/commit/89b7692780baad9470fcfe994f486883a30a44a3))
- Playback: a short fade on pause and on resume, none when a song starts fresh ([`b2a5b28`](https://github.com/maxcodl/PaperPlay/commit/b2a5b28cd17bae5ce522a7ed09015de6a4449624))
- Desktop: picking a music folder logs what it found, reports a read error, and answers on the window's own thread ([`9bd9756`](https://github.com/maxcodl/PaperPlay/commit/9bd975635f79badf42696bd94add90dc77d4a0eb))
- Missing songs: the add button says why it cannot add instead of doing nothing ([`ddb0566`](https://github.com/maxcodl/PaperPlay/commit/ddb0566a1774dea0fc21f01ddc9469caba0929a4))
- Log: a removed song names the code that removed it ([`4a69017`](https://github.com/maxcodl/PaperPlay/commit/4a6901777495ee916cdd94c68e3bc85b45b944a3))
- Devices: a screen with nothing playing follows the paired device that plays ([`1925fcc`](https://github.com/maxcodl/PaperPlay/commit/1925fcc9c6594a9f485ca809660f01fedc78e337))
- Playback: the song and the next two download in full, so seeking in them is instant ([`8db8e2b`](https://github.com/maxcodl/PaperPlay/commit/8db8e2b3deb432190044af0225060c4a048ac586))
- Desktop player: a stream end right after a seek is not the end of the song, the song reopens at the place asked for ([`e7190be`](https://github.com/maxcodl/PaperPlay/commit/e7190be5314df6e800f341b177038c7159568646))
- Desktop: Open in Telegram uses the t.me link, a browser cannot open tg:// ([`b2a8578`](https://github.com/maxcodl/PaperPlay/commit/b2a85787ae98a8687e1f7a51aa11bb8e1e8998de))
- Desktop: the Duplicates page is a lazy list and gets no scrolling column, which crashed with an infinite height ([`57cc3cc`](https://github.com/maxcodl/PaperPlay/commit/57cc3ccde79270cd1efe82a30eb56794f01d2441))

**Full changes:** [v1.8.0...v1.8.1](https://github.com/maxcodl/PaperPlay/compare/v1.8.0...v1.8.1)

## [1.8.0] - 2026-11-16

### Added
- Auto filing switch, file now button and after-scan trigger ([`b249e15`](https://github.com/maxcodl/PaperPlay/commit/b249e156aaba7639a8ef6a8dd5226d19e641b317))
- Auto filer copies or downloads and uploads songs into main chat topics ([`05f26c7`](https://github.com/maxcodl/PaperPlay/commit/05f26c73471a1a679fa44e1bb40a58539f3c3633))
- Device addresses in a dropdown ([`ed33c67`](https://github.com/maxcodl/PaperPlay/commit/ed33c67787a2018ca8cc2bd469b1710877e8efd0))
- Log app lifecycle, system, network, screen and setting events ([`a4f810b`](https://github.com/maxcodl/PaperPlay/commit/a4f810ba0f8a37e882246c9425bd6073b83217de))
- Setting for how many messages each reading request asks about ([`3f0f141`](https://github.com/maxcodl/PaperPlay/commit/3f0f141482f4218195423afe6634e51d22e352db))
- Read the cover inside the start of the audio file when the post has no thumbnail ([`b0817e2`](https://github.com/maxcodl/PaperPlay/commit/b0817e25334bf674b3850f336ac685e7aeaf6867))
- Song info also asks LRCLIB, takes the closest title for songs with no artist, and logs each lookup ([`fcad995`](https://github.com/maxcodl/PaperPlay/commit/fcad99504ad5e3b5b285dfdb2731f24b2747999b))
- Scan removes songs whose post your account no longer sees and reports skipped posts and small songs ([`ac0e853`](https://github.com/maxcodl/PaperPlay/commit/ac0e85353d4f857478bc535c50cf2fb5bd6ee4fb))
- Search lists a matching artist first, above the songs ([`cf0e4d9`](https://github.com/maxcodl/PaperPlay/commit/cf0e4d913a516683ee3c248b0632357902952d05))
- Tapping a song on Song info left plays it ([`e156ed6`](https://github.com/maxcodl/PaperPlay/commit/e156ed679e84705e76fa6f27f320bc19a9a02f9c))
- Search ignores accents, forgives typos, matches inside words and ranks best match first ([`80a2934`](https://github.com/maxcodl/PaperPlay/commit/80a29342d7e23696b71d11908dc84f54bcf44224))
- Scan page steps also go to the activity log ([`e123e7c`](https://github.com/maxcodl/PaperPlay/commit/e123e7cfda7933cc918f4b3c9efc327357edea51))
- One Scan library page with a switch for each bot and the account; replaces repair and full rescan ([`7ebf215`](https://github.com/maxcodl/PaperPlay/commit/7ebf215691c8255708adc04a8c4c37bb0978bfba))
- Standby lyrics animation style, restore single lyric line widget ([`8cb8b2b`](https://github.com/maxcodl/PaperPlay/commit/8cb8b2bb4f5eec3e99e0df23dc32b4bd8693ebff))
- Standby alert icons, scrolling lyrics, two-tap exit, cover and accent colours ([`7d8f161`](https://github.com/maxcodl/PaperPlay/commit/7d8f16173e0fe8f72cd90f5ffd7b2f85fc20001d))
- Charging and notification icon support for standby, window bar hiding ([`a9514d8`](https://github.com/maxcodl/PaperPlay/commit/a9514d80d7c8f2fad9733cdebf8a5e0a6a8ffacf))
- Standby visualizer follows the audio, seven new styles including ASCII ones ([`2261d21`](https://github.com/maxcodl/PaperPlay/commit/2261d21d58c520b9730e8500ca615321d99ce276))
- Live audio spectrum from the player for visuals ([`95cb586`](https://github.com/maxcodl/PaperPlay/commit/95cb58697f0d4fe6320fc891e804f866d8f08053))

### Fixed
- Update repository references from PaperPlay-compose to PaperPlay in various files ([`2936ebc`](https://github.com/maxcodl/PaperPlay/commit/2936ebcfbb0c346e9d8f667b8616276109a2533d))
- Inline song rows key by copy ([`d7ce71d`](https://github.com/maxcodl/PaperPlay/commit/d7ce71d36f320f6bd048ba2271a53ba6d4756de6))
- Top artists come from all results ([`fc0bffd`](https://github.com/maxcodl/PaperPlay/commit/fc0bffd90efbedde47798231e894673bfb40b0ac))
- Log share is file only and creates its folder ([`f6d043f`](https://github.com/maxcodl/PaperPlay/commit/f6d043f1432cbda623c3e551f3dae72830240f95))
- Play log sink drains held lines before going live ([`bcac654`](https://github.com/maxcodl/PaperPlay/commit/bcac65463b4e5e57cafde4d32767cd71da6d605c))
- Search ranks relevance first, wider typo prefixes, folds combining accents ([`7ee3632`](https://github.com/maxcodl/PaperPlay/commit/7ee3632efb331644b822e9ed092d2b6026622f5a))
- Auto filer retries after an hour, checks main chat, confirms delete ([`23fba31`](https://github.com/maxcodl/PaperPlay/commit/23fba31aa8aab75154c57414b94dfefb16a3c93a))
- Only the owner's account confirms a post is gone; account failure falls back to the bot ([`ce7524b`](https://github.com/maxcodl/PaperPlay/commit/ce7524b4cb8b58071f9ed790a447de561dce3a51))
- Empty read of a cached file refreshes its path ([`041c83b`](https://github.com/maxcodl/PaperPlay/commit/041c83b760975277ee6171c968e47cd2bf9ebda4))
- Rescan moves on to the next reader when a lookup is refused ([`814a6b5`](https://github.com/maxcodl/PaperPlay/commit/814a6b5b8f0d0bc8e289c2a17d005d70543cf927))
- Skip from pause counts as playing for the download window ([`3405e16`](https://github.com/maxcodl/PaperPlay/commit/3405e16680339fb8fda809bba46762c737cd498e))
- Log export and rotation share a lock, copy a fixed snapshot ([`8c02f69`](https://github.com/maxcodl/PaperPlay/commit/8c02f69f5cb87c805b9b5d6b3f3d056f7378441e))
- Covers retry unanswered songs, keep chosen covers, skip streaming files ([`5a7cdb6`](https://github.com/maxcodl/PaperPlay/commit/5a7cdb6304b08e490388331e2cc513e84f2baf28))
- Account reads fail on stalled paging and deletes stay unresolved when unchecked ([`7ae73ba`](https://github.com/maxcodl/PaperPlay/commit/7ae73ba4e20f2009895f031221d2044539aeba8f))
- Account read keeps no stale snapshot and prunes only what it covered ([`c86a083`](https://github.com/maxcodl/PaperPlay/commit/c86a08365356f8d189c4a7d36275acf3f2a239a2))
- Network log line formats the supplied capabilities ([`753b107`](https://github.com/maxcodl/PaperPlay/commit/753b10733691b790d512bef07b2c8fe03f4ee046))
- Auto filer passes the duration as an Int ([`54e5033`](https://github.com/maxcodl/PaperPlay/commit/54e503388a1429db16f011f8deeba5225954e4c9))
- Cover search skips the background rate-limit queue and times out after 8 s ([`88e72d2`](https://github.com/maxcodl/PaperPlay/commit/88e72d267515a4eedac45b6cfc0b5021c47286b6))
- Enter in the cover and tag search boxes runs the search ([`6cd28f0`](https://github.com/maxcodl/PaperPlay/commit/6cd28f07b254723304e858ea31a971805d30eeb1))
- Share and save the log as a streamed file, not one big string ([`6475c00`](https://github.com/maxcodl/PaperPlay/commit/6475c00f4ad2254ca7e9164ea62d7484c55b7c52))
- Restoring the saved index on the account page runs off the main thread ([`0cca480`](https://github.com/maxcodl/PaperPlay/commit/0cca4809fc35640bf9925f6d737ca538aca1de2b))
- Library reads stay stable while posts are deleted; Delete button follows the mini player ([`f1ced93`](https://github.com/maxcodl/PaperPlay/commit/f1ced93703d006f8d90910c517952b50e66f30f6))
- Account reads the chat only after loading it, so a new session no longer says chat not found ([`fb5b18a`](https://github.com/maxcodl/PaperPlay/commit/fb5b18a9a58ee8210ad6091cb5d1307d4cbe1a99))
- Account delete checks what is really gone and logs Telegram's reason ([`6f9cbfd`](https://github.com/maxcodl/PaperPlay/commit/6f9cbfd60b9adf6b905ba095cf8d8d13a8c1e56b))
- Song info tries title and artist swapped when nothing matched ([`9e174fc`](https://github.com/maxcodl/PaperPlay/commit/9e174fc92e62badaef7bbcbd20279512ca7516a1))
- Covers give up for good only when Telegram answered, log why a cover is missing, account knows every library chat ([`0006641`](https://github.com/maxcodl/PaperPlay/commit/00066414dc510c3937e4bd170c80ab92b3ac1005))
- Song info and covers are not asked again by themselves; a scan from the scan page asks for everything again ([`7a3e7c9`](https://github.com/maxcodl/PaperPlay/commit/7a3e7c9e8cfd19ac42c4eb4305121d062ec6284c))
- No automatic full rescan at start; only posts newer than the last read ([`d2ff80b`](https://github.com/maxcodl/PaperPlay/commit/d2ff80b564e1b4f314a04d76984bf451eb0ee50c))
- Covers also read Telegram thumbnails through your account, and songs given up on are tried again once ([`d7cfb32`](https://github.com/maxcodl/PaperPlay/commit/d7cfb329dfa74d2d198d377f9fdbc27b30c5a0af))
- Repeat posts kept as copies are not counted as missing; scan log shows how many ([`5abcbbd`](https://github.com/maxcodl/PaperPlay/commit/5abcbbd75031c951179e120d15fac953d276f8c9))
- Posts missing from the library are found by message id, not by matching title and artist ([`56f2428`](https://github.com/maxcodl/PaperPlay/commit/56f24286544c659c359ecb37cf78508cca552400))
- Account scan adds every main chat post the library has no row for, and logs how many it saw ([`d1c35eb`](https://github.com/maxcodl/PaperPlay/commit/d1c35ebc7b01f79dcf0cd1ad9b0394844757b63e))
- Full rescan shows and paces the check of saved songs, in batches of 100 ([`f81b29e`](https://github.com/maxcodl/PaperPlay/commit/f81b29eeee1f00e7c062e133d12307b28e0be172))
- Start the volume watcher after playbackMeta exists, it crashed on start ([`484e5d5`](https://github.com/maxcodl/PaperPlay/commit/484e5d55cd10c4680def7237d5ff63118b7f9ba5))
- Next and previous start playing when paused ([`b566ae0`](https://github.com/maxcodl/PaperPlay/commit/b566ae010ded344402ce71978c3db59c2393da40))
- Full rescan also reads with extra bots and the account; account on by default in repair ([`fb15345`](https://github.com/maxcodl/PaperPlay/commit/fb1534544c9ae35684a4df294373daedc573935f))
- Status toast stays dismissed during a scan and slides out fully ([`541125f`](https://github.com/maxcodl/PaperPlay/commit/541125f4e199588841e072faf98a5fe58698ed3f))

### Improved
- Bound memory caches, fix lifecycle leaks, and defer engine startup ([`fd71732`](https://github.com/maxcodl/PaperPlay/commit/fd7173253bbf9de3ce4024921619480c7b87e97b))

### Documentation
- Checklist for the event log, log sharing and standby lyrics ([`c2d43d2`](https://github.com/maxcodl/PaperPlay/commit/c2d43d262d9df4c72a04eb8b3f15be4e308bb8f0))
- AGENTS.md with rules for contributors and agents ([`e1f3b64`](https://github.com/maxcodl/PaperPlay/commit/e1f3b648d97d02efad5a35d70f066c53105499a8))
- Checklist for the scan page, account reading, duplicates and rate limits ([`bc847a4`](https://github.com/maxcodl/PaperPlay/commit/bc847a43e062b112e26e940851c25d974e61210c))
- Checklist for the logging, crash records and memory line ([`61068b4`](https://github.com/maxcodl/PaperPlay/commit/61068b4f9e03d29299ec1baa72c5c782cfa7e945))
- Checklist for the standby lyrics, colours and exit changes ([`4d9a536`](https://github.com/maxcodl/PaperPlay/commit/4d9a536a8caecebc2e61db444a2980d6bf6c8e0e))
- Checklist for the standby visualizer and alert icons ([`24df364`](https://github.com/maxcodl/PaperPlay/commit/24df364f85911a7a7f0028a9a3ebd33852ae05e1))

### Other changes
- Checklist: rewind, packaging, repository ([`30bc86d`](https://github.com/maxcodl/PaperPlay/commit/30bc86dac61dbccac68a608098879cd6b7a266f2))
- Agents: touch blocking, artists, covers, merge rules, rewind and process rules ([`c67617a`](https://github.com/maxcodl/PaperPlay/commit/c67617a017b1bba6a8f3afaaa1b1959d394d9ff5))
- Readme: rewind, lyrics choice, compilation covers ([`08e8a74`](https://github.com/maxcodl/PaperPlay/commit/08e8a747cafa32d032653360ca71c867fa9b62f7))
- Desktop package: include java.management so the memory line works ([`8db322d`](https://github.com/maxcodl/PaperPlay/commit/8db322d4b85f2a3a3ec88f6702a0df19a64a4d40))
- Rewind: one press plays the song again from the start, a second press within 2.5 s goes back, and the first song only restarts ([`ad943f2`](https://github.com/maxcodl/PaperPlay/commit/ad943f2daf8883f6cf7a03b7763d35e5e78fae1f))
- Covers: a compilation is never the cover or the first album match, and a button resets songs that got one ([`f0e2e46`](https://github.com/maxcodl/PaperPlay/commit/f0e2e46076aae35d20e8c7041c199bbea0702ed5))
- Player and bars take the touches that land on them, so nothing behind is pressed ([`f6258e1`](https://github.com/maxcodl/PaperPlay/commit/f6258e13b598cf60c75f0c945ae42bdca1e9a140))
- Checklist: audio, lyrics and covers ([`70deac6`](https://github.com/maxcodl/PaperPlay/commit/70deac603c4a8ca22f563f25842a41b9e28d843b))
- Lyrics: pick another version (original, romanized, translation, other records) for a song ([`640f729`](https://github.com/maxcodl/PaperPlay/commit/640f7297fbd7fbd57e2d89f8bfc83783002f7dc0))
- Sync: lyrics converge, a text chosen by hand wins, the choice and its time travel ([`5e818ca`](https://github.com/maxcodl/PaperPlay/commit/5e818caa59cf398b6efad64b9d72f402659f6ac6))
- Sync: devices pick the same album tags and cover when each found its own ([`99a29b6`](https://github.com/maxcodl/PaperPlay/commit/99a29b6e889e879e11bb9d2659c1c178129d9088))
- Audio: float output so 24-bit files are not cut to 16 bits without dither, and log the output format ([`e19c680`](https://github.com/maxcodl/PaperPlay/commit/e19c680b9d94112f2eea8f698f34b897b7a9356a))
- Checklist: status at the end of 16 Nov ([`7e8b24a`](https://github.com/maxcodl/PaperPlay/commit/7e8b24acbd9c971a6ce933b7c7974088aea8a6ae))
- Agents: git status before builds, release script, known failing test ([`32dbc26`](https://github.com/maxcodl/PaperPlay/commit/32dbc26579562edaa1b9115f7e5398d2c3d794fc))
- Readme: scan page, topic lists, shared player and sync, tappable artists, Spotify account list ([`672bcf2`](https://github.com/maxcodl/PaperPlay/commit/672bcf27dd97903f2aa6420a17885ad6ecb7f2bd))
- Player and song menu: tappable artists and album, go to artist or album ([`1864dbc`](https://github.com/maxcodl/PaperPlay/commit/1864dbcb91b7c9b2dfa4e855f1f300a5cf7ff466))
- Artists: a credit splits into artists, each opens its own page, and so does the album ([`a3a45fc`](https://github.com/maxcodl/PaperPlay/commit/a3a45fc247da3408381229a0a32f7426dd088f95))
- Checklist: PC parity ([`f131b6f`](https://github.com/maxcodl/PaperPlay/commit/f131b6f64aca9f80ba973a65bb50ad6b954815ae))
- Desktop: right click menu on songs, Alt+Left back, sharing to clipboard and Explorer, Spotify import in the sidebar, keep-on-device pin on every list ([`068c496`](https://github.com/maxcodl/PaperPlay/commit/068c4964b7227d9408ff3854b31e064772946934))
- Spotify: lists the account's own playlists for one-tap import ([`4319bec`](https://github.com/maxcodl/PaperPlay/commit/4319bec7fd0a91696e75f413d4fc921b74b081af))
- Sync: a Spotify playlist keeps its link and waiting list on every device ([`bd26de4`](https://github.com/maxcodl/PaperPlay/commit/bd26de4431029d84dffb9101f6420c482baecfd6))
- Sync: a brake on mass removal, removals are logged, a song posted again leaves the deletion record, and a clear button ([`d6873cc`](https://github.com/maxcodl/PaperPlay/commit/d6873cc271ba47fbccbd412f7aa9edf92375c278))
- Checklist: devices, sync and standby ([`8b3c5a2`](https://github.com/maxcodl/PaperPlay/commit/8b3c5a25206efe5e8e788787d1bcf33c7754c4c6))
- Standby: faded lyric list, plain lyrics, no-lyrics notice, grayscale cover ([`6a4e00c`](https://github.com/maxcodl/PaperPlay/commit/6a4e00cdc88e7891cc3d8302762dfb1ff9f08786))
- Devices: state with the sound output, stale states ignored, source switch waits for the other device ([`4d853a1`](https://github.com/maxcodl/PaperPlay/commit/4d853a132fab013a5cd285d23a754f049f71c2ae))
- Desktop: the real Windows sound output name and type ([`edea23f`](https://github.com/maxcodl/PaperPlay/commit/edea23f423b17fcd0c8c2f8936bd1d0340288abe))
- Sync: songs deleted on one device are removed on the other, the record travels on ([`cf5ff54`](https://github.com/maxcodl/PaperPlay/commit/cf5ff54e4ee23c379e8308c06149a58d4abca49c))
- Agents: ui rules ([`11ba1c6`](https://github.com/maxcodl/PaperPlay/commit/11ba1c6c9c66108cb06a39c995d5a53f8c193610))
- Checklist: sidebar tools row ([`5c39ee6`](https://github.com/maxcodl/PaperPlay/commit/5c39ee6e007e6c5f8e139522238575e6efaec1a7))
- Desktop sidebar: Tools is a row with an icon and fold arrow, Settings set apart by a divider ([`086f578`](https://github.com/maxcodl/PaperPlay/commit/086f5781b72ec2eb4a6f02e29bb79d9f7e7a798e))
- Player: says which device the music is playing on ([`2c3cc8c`](https://github.com/maxcodl/PaperPlay/commit/2c3cc8ca4e115dc83b21fb506cbbe0059ffe8853))
- Desktop db: wait up to 30 s for a locked database and use WAL, so concurrent writes do not close the app ([`87965cc`](https://github.com/maxcodl/PaperPlay/commit/87965cc840db9ec07cc280376316a5e3d9a0f24f))
- Sync: song info, lyrics and covers fill in between linked devices; hand-made data wins over automatic ([`3124d43`](https://github.com/maxcodl/PaperPlay/commit/3124d4331404b34a04079585a5f76de68905d16f))
- Player: shows and controls the other device's song, a one-tap source switch, and a strip when another device plays ([`7e5df3a`](https://github.com/maxcodl/PaperPlay/commit/7e5df3a2b0f15207caa0bf383c629ae7ee2f45b5))
- Devices: seek and play-this-song controls, position in the playing state, and a switchable active output ([`03cd7f8`](https://github.com/maxcodl/PaperPlay/commit/03cd7f889b6785a5d4e1c7ba36efbd8993bab75c))
- Scan page: the account counter says songs are added when the read ends ([`d8f597a`](https://github.com/maxcodl/PaperPlay/commit/d8f597a10e94d6cbe1b81c0d4a3ac806cf7303f8))
- Desktop sidebar: Tools is a drop-down with the everyday tools ([`b28dc0f`](https://github.com/maxcodl/PaperPlay/commit/b28dc0faab5e95175e1389bbdff4811cb8ef3f3f))
- Telegram topic lists on Home and in the desktop sidebar, apart from the playlists ([`d7fd42b`](https://github.com/maxcodl/PaperPlay/commit/d7fd42b5422730e1fec61eaabdb67ed7a29a711d))
- Settings: explanations sit behind an info button next to each title ([`d7dc92f`](https://github.com/maxcodl/PaperPlay/commit/d7dc92f35cb1ed02c716df0f7edaefe5aa08d705))
- Library: the Telegram topic lists under Playlists refresh with the library and include topics Telegram never named ([`114c6dc`](https://github.com/maxcodl/PaperPlay/commit/114c6dc562a2c44633a1e1d19ec03805e6993b7a))
- Delete: steps go to the Activity log and the playback log ([`d63185b`](https://github.com/maxcodl/PaperPlay/commit/d63185b53a47fb3620e3f00704169e68bfbbdd13))
- Duplicates: show a running delete's progress while the page loads, and do not check for gone posts during a delete ([`907e9b9`](https://github.com/maxcodl/PaperPlay/commit/907e9b9e22f559cb50cca9099607c1e255e7d792))
- Delete: your account deletes first, in calls of 100, so progress shows and old posts are not refused one by one ([`cd14eb9`](https://github.com/maxcodl/PaperPlay/commit/cd14eb932a95ffff255cba8e66e272540df66f81))
- Log which code removes a song from the library ([`3a485ab`](https://github.com/maxcodl/PaperPlay/commit/3a485ab92b5db94be4f709a4c5b1b5217f6fdcd2))
- Delete: a post to keep or a listed post counts as gone only when your account no longer sees it ([`69fea0f`](https://github.com/maxcodl/PaperPlay/commit/69fea0f6efa072d431b40c3a9351932e6876c10f))
- Duplicates: a lower quality copy is always suggested for deletion, in any topic ([`8c65165`](https://github.com/maxcodl/PaperPlay/commit/8c65165f877d577a4489a2b067ddbf4bcf37d4fa))
- Stream: when TDLib moves a finished download out of temp, ask it for the new path instead of stopping the song ([`f25e1a7`](https://github.com/maxcodl/PaperPlay/commit/f25e1a70fa27e341e69adb7e376160af0c334292))
- Delete: a post the bot reports as not found only counts as gone when your account no longer sees it ([`83215c0`](https://github.com/maxcodl/PaperPlay/commit/83215c043a31088c4fba933e2630a21d79f91a02))
- Account scan fetches the names of the main chat's topics, so repeats are not listed under 'Unnamed topic' ([`d009d44`](https://github.com/maxcodl/PaperPlay/commit/d009d449f6f6a2f9b8b345075985144148dffc71))
- Automatic reads are held to 50 requests a minute ([`951f328`](https://github.com/maxcodl/PaperPlay/commit/951f32854db567dc58494016ca1189dab7ebfe72))
- Only a scan the owner starts uses the messages-per-request setting; automatic reads use 100 ([`16cd7c8`](https://github.com/maxcodl/PaperPlay/commit/16cd7c8983ca308aea2e209969bb4f7cb5a59f28))
- Reading: after two waits in a row with a big request the size goes back to 100 and the read stops ([`45bae3a`](https://github.com/maxcodl/PaperPlay/commit/45bae3a54ab5fd6ba68bf5e5e1d48b9def64fe53))
- Duplicates: never mark every post of a group, even when another group also ticks one of them ([`04f679b`](https://github.com/maxcodl/PaperPlay/commit/04f679be0a871778d47f0be4b1c709d0ccfd3d50))
- Scan page counts posts while the account reads, since repeats are included ([`c66c990`](https://github.com/maxcodl/PaperPlay/commit/c66c990fb47bd18c80e915a6a223fa4ddd5e8d27))
- Account read shows the real count while reading, not an estimate that ran ahead and dropped back ([`f474e59`](https://github.com/maxcodl/PaperPlay/commit/f474e5901529a2e99a06617b89e80ec1648f37fd))
- Account read keeps going past an empty page and logs Telegram's own post count ([`30e75b4`](https://github.com/maxcodl/PaperPlay/commit/30e75b4d6deb1106fbead8cdacf1058fbb40d367))
- Up to 500 ids per reading request, put back to 100 if Telegram refuses; scan notes come from the full read ([`8e8f668`](https://github.com/maxcodl/PaperPlay/commit/8e8f668ae6c5ffc7bc5dadd6f9bc110f8238ac84))
- Log how many posts each account search returned ([`4736ee5`](https://github.com/maxcodl/PaperPlay/commit/4736ee5881e63208ad2b3c706513f6f700000d7d))
- Ui: Home placeholders cross-fade into the page instead of going blank first ([`018019e`](https://github.com/maxcodl/PaperPlay/commit/018019e48f28b46b2403cb9f199cd74820b1b8b8))
- Ui: Telegram page shows account state and no speed dials, account copy speed moves to the account page, logout tells what happened, up to 200 messages per request ([`fe9db5d`](https://github.com/maxcodl/PaperPlay/commit/fe9db5dc43f67cbbadd0266aef29d603d1e46698))
- Ui: Songs list also shows every repeat post of a file as its own row ([`6191e14`](https://github.com/maxcodl/PaperPlay/commit/6191e14a0e16c40ce98e0f58060369975cbf1fa4))
- Ui: Delete button on Duplicates sits just above the bottom bar ([`e236fb6`](https://github.com/maxcodl/PaperPlay/commit/e236fb6eeb3eebe1c5a9204a57d6b46063bab90e))
- Ui: song rows always show format, bitrate and size, format first and size on the right ([`10cbcb0`](https://github.com/maxcodl/PaperPlay/commit/10cbcb028db40eff5214c5d2ebd578607652a7f5))
- Ui: Home shows all placeholders first and fades in once ready; placeholders shimmer, covers too ([`916b9ff`](https://github.com/maxcodl/PaperPlay/commit/916b9ffdc9a8929c17eb6fe26be6494738968cb0))
- Ui: merge Devices and Storage on Profile ([`046041b`](https://github.com/maxcodl/PaperPlay/commit/046041b0b1678fa61ab8c60b3451033c301458e7))
- Ui: shorter Library list on Profile ([`fe931da`](https://github.com/maxcodl/PaperPlay/commit/fe931da504f62587aab825c829f42a2b9bf4e19f))

**Full changes:** [v1.7.0...v1.8.0](https://github.com/maxcodl/PaperPlay/compare/v1.7.0...v1.8.0)

## [1.7.0] - 2026-11-14

### Added

- Record crashes, how the last run ended, and the system log ([`c2cf455`](https://github.com/maxcodl/PaperPlay/commit/c2cf455c5855404b6ce20add2b6e6f78d0aaff95))
- Share the full log as a file or text from the Log page ([`01bf96a`](https://github.com/maxcodl/PaperPlay/commit/01bf96abcc58baa1882e36a85cd5c27e3d8e0d45))
- Memory line every ten seconds in the log ([`fdea970`](https://github.com/maxcodl/PaperPlay/commit/fdea970f493a33a9f5e41442c3042ea0a95a4ae0))
- Playback log kept on disk with every player, stream and file event ([`5e97c42`](https://github.com/maxcodl/PaperPlay/commit/5e97c42508f42dc926854f9b00aab73f4b79cbf6))

**Full changes:** [v1.6.0...v1.7.0](https://github.com/maxcodl/PaperPlay/compare/v1.6.0...v1.7.0)

## [1.6.0] - 2026-11-14

### Added

- Scan banner shows the bot's name ([`de64d8a`](https://github.com/maxcodl/PaperPlay/commit/de64d8a243fe4c4dbce0d530915ee7cf5f83be35))
- Indexing count goes up smoothly ([`95d1434`](https://github.com/maxcodl/PaperPlay/commit/95d143414fdafa2781c8109a9c47c6ed3513a5c1))

### Documentation

- Checklist for indexing count and bot names ([`3877980`](https://github.com/maxcodl/PaperPlay/commit/38779808794ff936470ad5204c4a7e195945e209))

**Full changes:** [v1.5.0...v1.6.0](https://github.com/maxcodl/PaperPlay/compare/v1.5.0...v1.6.0)

## [1.5.0] - 2026-11-14

### Added

- Smooth sync counter, full scan shows which bot or account is reading ([`427f18b`](https://github.com/maxcodl/PaperPlay/commit/427f18b24bbfc69fcb5cac50b6990aa4c73b3193))
- Duplicates delete counts one by one, page updates live and scrolls to top ([`3c5c03f`](https://github.com/maxcodl/PaperPlay/commit/3c5c03fb9a02f3495151fe2b231f346834321997))

### Documentation

- Checklist for the last round ([`26768dd`](https://github.com/maxcodl/PaperPlay/commit/26768ddf43350b869109d465b3e78890fd5e3eee))

**Full changes:** [v1.4.0...v1.5.0](https://github.com/maxcodl/PaperPlay/compare/v1.4.0...v1.5.0)

## [1.4.0] - 2026-11-14

### Added

- Library settings in drop-downs, read with other bots after a rescan ([`80ca842`](https://github.com/maxcodl/PaperPlay/commit/80ca842f2d7e78b59a7aa5d80126a33d7ccf4148))
- Song info left page redesign, tasks open the live list ([`d49ccc7`](https://github.com/maxcodl/PaperPlay/commit/d49ccc7866b848fd1362a8350273c1dd14b99160))
- Faster song info, Deezer first ([`e8ce2df`](https://github.com/maxcodl/PaperPlay/commit/e8ce2df67af12f3959815d036852880943d98276))
- Reading speed adjusts itself ([`977f251`](https://github.com/maxcodl/PaperPlay/commit/977f251e00e52f5084649b9c389ac93a9da115e5))
- Search songs by language ([`2bbe168`](https://github.com/maxcodl/PaperPlay/commit/2bbe168e93d30b830aab7da785a3e932cba65b1e))
- Duplicates page with a floating delete, auto-ticked extras, topic names and a lazy list ([`fbb4fdb`](https://github.com/maxcodl/PaperPlay/commit/fbb4fdb9e735fafeecf9f7fe7b91b0c7e668c304))
- Spotify playlists list missing songs greyed out, with copy links, and lists remember their sort ([`d14810f`](https://github.com/maxcodl/PaperPlay/commit/d14810f0566d8ff9135bbe2870d1e2caac41897a))
- Home skeletons, steadier covers, swipeable tiles, coloured toasts and a mini player that swipes away ([`f1988d3`](https://github.com/maxcodl/PaperPlay/commit/f1988d3c8c1fe196845d1f1d31119a3d0afb2f70))
- Upload a music folder in place, ask before subfolders, skip songs under 2 MB ([`c4443aa`](https://github.com/maxcodl/PaperPlay/commit/c4443aae0c864b8f0a942cd7d469dd94263d5006))
- Progress for missing and low-quality covers in the tasks list and the notification ([`d8b4613`](https://github.com/maxcodl/PaperPlay/commit/d8b46138c7820eed428410d23de421190b01fc7d))
- Read a song's length from its file header ([`edce335`](https://github.com/maxcodl/PaperPlay/commit/edce335d5e21b5b1cca795a69db79c113afe9fe3))
- Show an update dialog on every launch when a newer release exists ([`0656b1c`](https://github.com/maxcodl/PaperPlay/commit/0656b1c34ceb68a9702f3df83113279bf002be80))
- The in-app logo follows the app theme ([`84afc56`](https://github.com/maxcodl/PaperPlay/commit/84afc56dfc1b917f9657d4a13fd618db5f76d7f9))

### Fixed

- Duplicate delete goes through the Bot API per post ([`a830641`](https://github.com/maxcodl/PaperPlay/commit/a8306414c099e689217ba33db47e8bb45c799a06))
- Windows release bundles a Java 25 runtime so the installer starts ([`5273468`](https://github.com/maxcodl/PaperPlay/commit/5273468b3fdbf33f2069a1cc6a1cf004162f200c))
- Onboarding shows the chosen photo and no false Not ready yet on the bot page ([`0ed267e`](https://github.com/maxcodl/PaperPlay/commit/0ed267ea7b77791e7b3b9ad68184ebad5965b075))
- Uploads use the request shape of the loaded TDLib, run in parallel and send the song length ([`48bf3ad`](https://github.com/maxcodl/PaperPlay/commit/48bf3ad0500c78b66a4da61e8f90ce7489798d8d))
- The Windows release includes TDLib so it can reach Telegram ([`734f350`](https://github.com/maxcodl/PaperPlay/commit/734f3500d0f8dafe5108fe94aeb88d3c11e63dab))
- CI ProGuard reads the JDK 17 classes because the Gradle JDK 25 has no jmods ([`7abe514`](https://github.com/maxcodl/PaperPlay/commit/7abe5148acd33e9f25ad6dbdd090e62a74baec38))
- Setup tells the user to remove an older per-machine install ([`27e0c98`](https://github.com/maxcodl/PaperPlay/commit/27e0c9861fea9d9695bd7fcfd359295429b48362))
- GitHub Windows release uses the same minified build and Inno installer as the release script ([`501cd20`](https://github.com/maxcodl/PaperPlay/commit/501cd20349d674146ff23ea8f624763df8aa8650))
- Package Compose resources on Android so the settings logo no longer crashes ([`cfba237`](https://github.com/maxcodl/PaperPlay/commit/cfba237764ef0308f8aa134c0a3eb4ba18acda74))

### Documentation

- Checklist and readme ([`222d1e9`](https://github.com/maxcodl/PaperPlay/commit/222d1e9b7faaa16e726b4b47599fb6e88de77227))
- Checklist for this round of work ([`163609f`](https://github.com/maxcodl/PaperPlay/commit/163609f461c44a41389e265e1b20270f64ffd95a))
- TDLib is in the repository, CI fixes in the checklist ([`3b2d01e`](https://github.com/maxcodl/PaperPlay/commit/3b2d01eb2b55962758383dad291067ff26278100))
- The update check runs at every launch and shows a dialog ([`ed49815`](https://github.com/maxcodl/PaperPlay/commit/ed49815a2b6b0d395da7a234bdb9640bba8ac9d4))
- Checklist for the settings crash, themed logo and one Windows installer ([`cd3c93e`](https://github.com/maxcodl/PaperPlay/commit/cd3c93e08d2a32d0a02502da9e8460b030307e1c))
- Update the README and the checklist for releases, the updater, About, logout and the merge-back rule ([`cc1ff44`](https://github.com/maxcodl/PaperPlay/commit/cc1ff44979c3a0acc12797453346eab4110ebd94))

**Full changes:** [v1.3.1...v1.4.0](https://github.com/maxcodl/PaperPlay/compare/v1.3.1...v1.4.0)

## [1.3.1] - 2026-11-14

### Fixed

- The in-app logo uses the launcher icon's own plane image instead of a redrawn badge ([`2a81d2c`](https://github.com/maxcodl/PaperPlay/commit/2a81d2c27e2d9ce24579a0c5a4e05413a16fd68f))

**Full changes:** [v1.3.0...v1.3.1](https://github.com/maxcodl/PaperPlay/compare/v1.3.0...v1.3.1)

## [1.3.0] - 2026-11-14

### Added

- Compact About page with drop-down rows for the update channel and installation method ([`111eced`](https://github.com/maxcodl/PaperPlay/commit/111eced1349e77c0374146f8b4b7492336f28acd))
- Real app icon with a plane-hits-the-note animation, animated tour background, About card on Profile ([`32e150b`](https://github.com/maxcodl/PaperPlay/commit/32e150b76cf79e8bc8b51b38bbbbed229596f246))
- Settings grouped under headings with About last; About shows the installation method with Shizuku below ([`d3a9a6b`](https://github.com/maxcodl/PaperPlay/commit/d3a9a6b58c6ded7f81620da2ed3d67f40fa74917))
- Log out options (everything, bot only, account only) and log out with delete all data ([`e84d831`](https://github.com/maxcodl/PaperPlay/commit/e84d8317d34bb094af254f22bd31d46f6e433281))
- Optional Shizuku installer for updates, with permission prompts and toasts ([`84b797d`](https://github.com/maxcodl/PaperPlay/commit/84b797d6e66243b5b935b6c8bd8188d91969604f))
- Install updates on Windows by running the downloaded setup; Linux opens the release page ([`fdb136d`](https://github.com/maxcodl/PaperPlay/commit/fdb136d6158e9e4ff875ea16c7d35a9c1637e3f7))
- Open the install permission screen at once and continue the update when it is allowed ([`e6837b8`](https://github.com/maxcodl/PaperPlay/commit/e6837b891d1ce91bf880132493d3daea3c21eec6))
- Install updates on Android through the package installer, with a permission check ([`bd80e0d`](https://github.com/maxcodl/PaperPlay/commit/bd80e0da076083bdccd3f7fac62176136950cde5))
- About page with update check, update choices and the Made by Max footer ([`69cc5ec`](https://github.com/maxcodl/PaperPlay/commit/69cc5ecf38abbdd21ab2932d0eb7a01bd18304c0))
- Update logic - versions, the GitHub release feed and an update service ([`aede1b0`](https://github.com/maxcodl/PaperPlay/commit/aede1b090413594bc5bd351290aba51b436bb28b))
- Automatic versions, releases and change logs from the commit subjects ([`229efc2`](https://github.com/maxcodl/PaperPlay/commit/229efc24495dba09e543763fd8cf59a93a77f575))

### Fixed

- Import the state delegates the drop-down row needs ([`6d941db`](https://github.com/maxcodl/PaperPlay/commit/6d941db36f74535aea572e27213399b1861f57f6))
- A running Shizuku counts as installed even when the package lookup is hidden ([`928410c`](https://github.com/maxcodl/PaperPlay/commit/928410c84ffb5ca6cea21da9d5523aedc39c2c8c))
- Pass the update service to the Profile screen after the positional arguments ([`ee9b88e`](https://github.com/maxcodl/PaperPlay/commit/ee9b88e703cd75b449c843171eb0de022ae6f888))
- A mention of BREAKING CHANGE in prose no longer counts as a major bump ([`8e1a546`](https://github.com/maxcodl/PaperPlay/commit/8e1a546dbc63732be138eef72115431ee0f57433))

### Documentation

- Checklist entries for logout options, grouped Settings, About and the new logo ([`262f8a1`](https://github.com/maxcodl/PaperPlay/commit/262f8a1faa02a6d366f6398b36167fd8d1554cbf))
- Describe in-app updates and update the checklist ([`bf102a3`](https://github.com/maxcodl/PaperPlay/commit/bf102a3c35826abcb674646858ab3cebf3fe7fd9))
- Rewrite the README, update the checklist ([`4fae430`](https://github.com/maxcodl/PaperPlay/commit/4fae4306dd39237efbf8bc72e43c3370d4953ac8))
- Motion work, CI state, open items ([`5656ac2`](https://github.com/maxcodl/PaperPlay/commit/5656ac287c8e1b0d291ad9804211ef3eaefe2317))

### Other changes

- Smoother UI: press feedback, title and cover crossfades, gliding grids, tabs keep their scroll ([`e650ade`](https://github.com/maxcodl/PaperPlay/commit/e650ade4c3a284dacdcdb84e8e2a1d68aed06548))
- Windows build: also run createDistributable so the zip step finds the app folder ([`a411086`](https://github.com/maxcodl/PaperPlay/commit/a411086213a7720af8ea3fc7aa20257fa0739ab4))
- Desktop motion: sidebar, panel, hover, overlay and tray menu ([`31e6dd5`](https://github.com/maxcodl/PaperPlay/commit/31e6dd52b23c767825302c3879229b32eab0ab89))
- Lists glide, covers fade in, nav pill uses the shared spring ([`15fccc6`](https://github.com/maxcodl/PaperPlay/commit/15fccc6347ee5589d1bb541f0ffd72bfc573c93e))
- Screens slide and fade between pages instead of switching instantly ([`723628e`](https://github.com/maxcodl/PaperPlay/commit/723628ef4e0da077261b9e9993d0bcf2b0a3ac74))
- Full player slides up and down, follows the finger and the back swipe ([`ee60f8d`](https://github.com/maxcodl/PaperPlay/commit/ee60f8d232ed3879ae78263077ef45bbb6e864f6))
- Motion tokens and a Reduce motion setting ([`100b17d`](https://github.com/maxcodl/PaperPlay/commit/100b17d91eb427b7348ceb81b27037eaf1699fc9))
- Announce each paired device once per run, not every 20-second dial ([`79a694d`](https://github.com/maxcodl/PaperPlay/commit/79a694d491d6c92cc5bdb2b53430b05b895c3eb9))
- Windows build: a missing TDLib release no longer fails the step ([`966e52b`](https://github.com/maxcodl/PaperPlay/commit/966e52b93938c2e5afe948b7e95da51ca7289343))
- Build the Android debug and release APKs and the Windows and Linux apps ([`056120b`](https://github.com/maxcodl/PaperPlay/commit/056120b8fe1bf84231a6911d9827285dd6415383))
- Workflow reads the signing secrets under the names the other repo uses ([`c9fed95`](https://github.com/maxcodl/PaperPlay/commit/c9fed953de14f17f3ddeb61bb2d33b10e18e7d86))
- Respect upload back-off, count real listening time, refuse delete without a main chat; update docs ([`b9e70bc`](https://github.com/maxcodl/PaperPlay/commit/b9e70bc482032339ee6c1accbd7846428ff8860a))
- Restore while connected: shut everything down first and wait for TDLib's receive loop ([`d2457e8`](https://github.com/maxcodl/PaperPlay/commit/d2457e8dc2598e2c6d50f1738daf552e83ce2e25))
- Checklist: audit of what the code contains ([`42d9aae`](https://github.com/maxcodl/PaperPlay/commit/42d9aaec2ecc958ec9a391015c62a238179b7783))
- Lock the release-group cache and time out idle loopback logins ([`42aa3f6`](https://github.com/maxcodl/PaperPlay/commit/42aa3f6985a920e5307947f423b969a17244b2ac))
- Fix keep-running setting, pairing lockout counters, shared import race and range parsing ([`b3001cf`](https://github.com/maxcodl/PaperPlay/commit/b3001cfc84b5e6c4282d7f561e0c86abcce93658))
- Workflow builds only the Android debug APK for now ([`691a094`](https://github.com/maxcodl/PaperPlay/commit/691a09470a396d8162e34f8c816ba3364464b4a9))
- Backup: background and standby settings follow the layout choice ([`fa77b73`](https://github.com/maxcodl/PaperPlay/commit/fa77b7307975eeae71feb13ec3c832d83e18ea1c))

**Full changes:** [e7a6417...v1.3.0](https://github.com/maxcodl/PaperPlay/compare/e7a6417...v1.3.0)
