package io.max.paperplay.desktop

import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Tray
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.window.Window
import androidx.compose.foundation.window.WindowDraggableArea
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import io.max.paperplay.core.app.AppServices
import io.max.paperplay.core.backup.BackupRestorer
import io.max.paperplay.core.backup.RestoreOptions
import io.max.paperplay.core.backup.desktopRestoreTarget
import io.max.paperplay.core.backup.fileBackupSource
import io.max.paperplay.ui.App
import io.max.paperplay.ui.AppEnv
import io.max.paperplay.ui.RestoreHooks
import java.io.File

private const val PICTURES = "*.jpg;*.jpeg;*.png;*.webp"

/**
 * Where tdjson.dll (and the libraries beside it) are found.
 *
 * Priority: PAPERPLAY_TDLIB env var → `native/` next to the app resources →
 * `native/` in the working directory → dev copy inside the Flutter tree.
 *
 * VLC loading is handled separately by VlcLoader inside JvmPlayerEngine; there
 * is no need to mix VLC paths into jna.library.path here.
 */
private fun tdlibDir(): String? = listOfNotNull(
    System.getenv("PAPERPLAY_TDLIB"),
    File(System.getProperty("compose.application.resources.dir") ?: ".", "native").path,
    File("native").path,
    "D:/Git forks/Teleplayer/windows/third_party/tdlib",
).firstOrNull { File(it, if (System.getProperty("os.name").startsWith("Windows")) "tdjson.dll" else "libtdjson.so").exists() }

private val t0 = System.nanoTime()
@Volatile private var liveServices: AppServices? = null

/** Appends elapsed milliseconds since main() began to startup.log in the app data folder. */
private fun mark(dir: File, what: String) {
    runCatching {
        dir.mkdirs()
        val ms = (System.nanoTime() - t0) / 1_000_000
        val sinceJvm = System.currentTimeMillis() - java.lang.management.ManagementFactory.getRuntimeMXBean().startTime
        File(dir, "startup.log").appendText("${java.time.LocalDateTime.now()}  +${ms} ms (jvm +${sinceJvm} ms)  $what\n")
    }
}

/** Every audio file in [roots]: files as given, folders searched through all subfolders. */
private fun audioFilesIn(roots: List<File>): List<String> = roots.flatMap { r ->
    if (r.isDirectory) r.walkTopDown().filter { it.isFile }.toList() else listOf(r)
}.filter { it.extension.lowercase() in io.max.paperplay.core.app.audioExtensions }.map { it.path }

/** A picked folder: its own songs, and each subfolder's songs (nested folders included) apart, for the user to confirm. */
private fun scanFolder(dir: File): io.max.paperplay.ui.app.FolderScan {
    fun songs(files: Sequence<File>, base: File) = files.filter { it.isFile && it.extension.lowercase() in io.max.paperplay.core.app.audioExtensions }
        .map { io.max.paperplay.ui.app.FolderSong(it.path, it.relativeTo(base).path, it.length()) }.toList()
    val top = songs(dir.listFiles().orEmpty().asSequence(), dir)
    val subs = dir.listFiles().orEmpty().filter { it.isDirectory }.sortedBy { it.name.lowercase() }
        .associate { it.name to songs(it.walkTopDown(), it) }.filterValues { it.isNotEmpty() }
    return io.max.paperplay.ui.app.FolderScan(top, subs) { chosen, ready -> ready(chosen.map { it.id }, false) }
}

private const val DEFAULT_DARK_SURFACE_ARGB = 0xFF111318.toInt()

/** Lets files and folders be dropped on the window; they go to the uploads page. */
private fun installFileDrop(window: java.awt.Window) {
    fun dragCount(e: java.awt.dnd.DropTargetDragEvent): Int = runCatching {
        if (e.transferable.isDataFlavorSupported(java.awt.datatransfer.DataFlavor.javaFileListFlavor)) {
            @Suppress("UNCHECKED_CAST")
            (e.transferable.getTransferData(java.awt.datatransfer.DataFlavor.javaFileListFlavor) as? List<File>)?.size ?: 1
        } else 1
    }.getOrDefault(1)

    val target = java.awt.dnd.DropTarget(window, java.awt.dnd.DnDConstants.ACTION_COPY, object : java.awt.dnd.DropTargetAdapter() {
        override fun drop(e: java.awt.dnd.DropTargetDropEvent) {
            try {
                e.acceptDrop(java.awt.dnd.DnDConstants.ACTION_COPY)
                if (!e.transferable.isDataFlavorSupported(java.awt.datatransfer.DataFlavor.javaFileListFlavor)) { e.dropComplete(false); return }
                @Suppress("UNCHECKED_CAST")
                val dropped = e.transferable.getTransferData(java.awt.datatransfer.DataFlavor.javaFileListFlavor) as List<File>
                val found = audioFilesIn(dropped)
                if (found.isNotEmpty()) io.max.paperplay.ui.app.IncomingDrops.files.value = io.max.paperplay.ui.app.IncomingDrops.files.value + found
                e.dropComplete(true)
            } catch (_: Exception) {
                e.dropComplete(false)
            } finally {
                io.max.paperplay.ui.app.IncomingDrops.dragging.value = false
                io.max.paperplay.ui.app.IncomingDrops.dragCount.value = 0
            }
        }
        override fun dragEnter(e: java.awt.dnd.DropTargetDragEvent) {
            e.acceptDrag(java.awt.dnd.DnDConstants.ACTION_COPY)
            io.max.paperplay.ui.app.IncomingDrops.dragCount.value = dragCount(e)
            io.max.paperplay.ui.app.IncomingDrops.dragging.value = true
        }
        override fun dragOver(e: java.awt.dnd.DropTargetDragEvent) {
            e.acceptDrag(java.awt.dnd.DnDConstants.ACTION_COPY)
            if (!io.max.paperplay.ui.app.IncomingDrops.dragging.value) {
                io.max.paperplay.ui.app.IncomingDrops.dragCount.value = dragCount(e)
                io.max.paperplay.ui.app.IncomingDrops.dragging.value = true
            }
        }
        override fun dragExit(dte: java.awt.dnd.DropTargetEvent) {
            io.max.paperplay.ui.app.IncomingDrops.dragging.value = false
            io.max.paperplay.ui.app.IncomingDrops.dragCount.value = 0
        }
    })
    // Compose's own canvas may hold a drop target of its own; put ours on every component so it is never skipped.
    fun apply(c: java.awt.Component) {
        runCatching { c.dropTarget = if (c === window) target else java.awt.dnd.DropTarget(c, java.awt.dnd.DnDConstants.ACTION_COPY, target) }
        if (c is java.awt.Container) c.components.forEach(::apply)
    }
    apply(window)
}

/** Held for the life of the process so the file lock is never collected and released early. */
private var instanceLock: Any? = null
private val showMain = kotlinx.coroutines.flow.MutableSharedFlow<Unit>(extraBufferCapacity = 1)

/** One line of JVM memory numbers: heap, non-heap, direct and mapped buffers, loaded classes, threads. */
private fun jvmMemoryLine(): String {
    val mb = 1024.0 * 1024.0
    fun f(x: Long) = "%.1f".format(x / mb)
    val mem = java.lang.management.ManagementFactory.getMemoryMXBean()
    val heap = mem.heapMemoryUsage
    val non = mem.nonHeapMemoryUsage
    val pools = java.lang.management.ManagementFactory.getPlatformMXBeans(java.lang.management.BufferPoolMXBean::class.java)
    fun pool(name: String) = pools.firstOrNull { it.name == name }?.memoryUsed ?: 0L
    return "Heap: ${f(heap.used)}/${f(heap.committed)} MB (max ${f(heap.max)}) | NonHeap: ${f(non.used)}/${f(non.committed)} MB | " +
        "DirectBuf: ${f(pool("direct"))} MB, mapped ${f(pool("mapped"))} MB | Classes: ${java.lang.management.ManagementFactory.getClassLoadingMXBean().loadedClassCount} | " +
        "Threads: ${java.lang.management.ManagementFactory.getThreadMXBean().threadCount}"
}

/** "playpause", "next", "previous" or "stop" from the keyboard media keys or the taskbar buttons. */
private fun handleMediaKey(key: String) {
    val p = (liveServices ?: return).playback
    when (key) {
        "playpause" -> if (p.nowPlayingStatic.value.isPlaying) p.pause() else p.play()
        "next" -> p.next()
        "previous" -> p.previous()
        "stop" -> p.pause()
    }
}

private val shutdownTarget = java.util.concurrent.atomic.AtomicReference<AppServices?>(null)

/** Stops TDLib, playback and SQLite once before the JVM exits, so native threads do not race C++ destructors. */
private fun shutdownServices() {
    val s = shutdownTarget.getAndSet(null) ?: return
    liveServices = null
    runCatching {
        kotlinx.coroutines.runBlocking {
            kotlinx.coroutines.withTimeoutOrNull(8_000) { s.shutdown() }
        }
    }
}

fun main(args: Array<String>) {
    if (System.getProperty("paperplay.motion.bench") == "true" || "--motion-bench" in args) {
        DesktopMotionBench.run(args)
        return
    }
    // GitHub's asset host rotates addresses and one of them can be unreachable here; Java uses the first and caches it, so a retry hit the same dead one.
    java.security.Security.setProperty("networkaddress.cache.ttl", "0")
    if (System.getProperty("os.name").orEmpty().startsWith("Windows", ignoreCase = true) &&
        System.getProperty("skiko.renderApi") == null &&
        System.getenv("SKIKO_RENDER_API") == null
    ) {
        System.setProperty("skiko.renderApi", "OPENGL")
    }
    io.max.paperplay.core.app.MemoryProbe.sample = ::jvmMemoryLine
    io.max.paperplay.core.app.MemoryProbe.echo = { println(it) }
    val logDir = File(System.getenv("APPDATA") ?: System.getProperty("user.home"), "PaperPlay")
    runCatching { File(logDir, "startup.log").takeIf { it.length() > 64_000 }?.delete() }
    mark(logDir, "main start")
    // One copy only: a second launch asks the running copy to show its window, then exits. The OS drops the lock if the process dies.
    val lock = runCatching {
        logDir.mkdirs()
        java.io.RandomAccessFile(File(logDir, "app.lock"), "rw").channel.tryLock()
    }
    if (lock.isSuccess && lock.getOrNull() == null) {
        mark(logDir, "another copy is running, asking it to show")
        runCatching {
            val port = File(logDir, "app.port").readText().trim().toInt()
            java.net.Socket(java.net.InetAddress.getLoopbackAddress(), port).use { it.getOutputStream().write(1) }
        }
        return
    }
    if (lock.isSuccess) runCatching {
        instanceLock = lock.getOrNull()
        val server = java.net.ServerSocket(0, 5, java.net.InetAddress.getLoopbackAddress())
        File(logDir, "app.port").writeText(server.localPort.toString())
        Thread {
            while (true) runCatching { server.accept().use { it.getInputStream().read(); showMain.tryEmit(Unit) } }
        }.apply { isDaemon = true; name = "single-instance" }.start()
    }
    Runtime.getRuntime().addShutdownHook(Thread(::shutdownServices, "paperplay-shutdown"))
    // Set jna.library.path for TDLib only. VlcLoader will append the VLC path
    // automatically when the first JvmPlayerEngine is created.
    tdlibDir()?.let { System.setProperty("jna.library.path", it) }
    // No share sheet on Windows: shared text goes to the clipboard, a shared file is shown in Explorer.
    io.max.paperplay.ui.app.BackupFiles.shareText = { text ->
        java.awt.Toolkit.getDefaultToolkit().systemClipboard.setContents(java.awt.datatransfer.StringSelection(text), null)
    }
    io.max.paperplay.ui.app.BackupFiles.shareFilePath = { _, path ->
        runCatching { ProcessBuilder("explorer.exe", "/select,", File(path).absolutePath).start() }
    }
    io.max.paperplay.ui.app.BackupFiles.shareFile = { fileName, text ->
        runCatching {
            val dir = File(System.getProperty("java.io.tmpdir"), "paperplay-shared").apply { mkdirs() }
            val f = File(dir, fileName).apply { writeText(text) }
            ProcessBuilder("explorer.exe", "/select,", f.absolutePath).start()
        }
    }
    io.max.paperplay.ui.app.BackupFiles.pickDestination = { name, onPicked ->
        javax.swing.SwingUtilities.invokeLater {
            val picked = NativeDialogs.saveFile("Save backup", name)
            if (picked == null) onPicked(null)
            else {
                val chosen = picked.let { if (it.extension.isEmpty()) File(it.path + ".zip") else it }
                onPicked(io.max.paperplay.ui.app.BackupDestination { path -> runCatching { File(path).copyTo(chosen, overwrite = true) }.isSuccess })
            }
        }
    }
    WindowsMedia.start(::handleMediaKey)
    application {
        val dir = File(System.getenv("APPDATA") ?: System.getProperty("user.home"), "PaperPlay")
        val target = desktopRestoreTarget(dir)
        val titleBar = androidx.compose.runtime.remember { arrayOfNulls<java.awt.Window>(1) }
        // Kept: a new one on every play or pause would redraw everything and forget what it holds (the tour closed at the next song).
        val env = androidx.compose.runtime.remember { AppEnv(
            restore = RestoreHooks(
                pickBackup = { onPicked ->
                    NativeDialogs.openFiles("Choose a backup", "*.zip").firstOrNull()?.let { onPicked(fileBackupSource(it.path)) }
                },
                restore = { source, pw -> BackupRestorer().restore(source, target, RestoreOptions(password = pw)) },
            ),
            libraryExists = { File(dir, "library.sqlite").exists() },
            // The window is removed while hidden in the tray, so a reopened window reuses the running services.
            createServices = { liveServices?.takeUnless { it.isShutDown } ?: AppServices(DesktopPlatform(dir)).also { liveServices = it; shutdownTarget.set(it) } },
            mark = { mark(dir, it) },
            pickImage = { onPicked ->
                val file = NativeDialogs.openFiles("Choose a picture", PICTURES).firstOrNull()
                if (file == null) onPicked(null) else onPicked(runCatching { file.readBytes() }.getOrNull())
            },
            pickPhoto = { onPicked ->
                val file = NativeDialogs.openFiles("Choose a photo", PICTURES).firstOrNull()
                if (file == null) onPicked(null)
                else onPicked(runCatching {
                    val folder = File(dir, "profile").apply { mkdirs() }
                    folder.listFiles()?.filter { it.name.startsWith("photo-") }?.forEach { it.delete() }
                    file.copyTo(File(folder, "photo-${System.currentTimeMillis()}.${file.extension}")).path
                }.getOrNull())
            },
            pickAudio = { onPicked ->
                val files = NativeDialogs.openFiles("Choose songs", io.max.paperplay.core.app.audioExtensions.joinToString(";") { "*.$it" }, multiple = true)
                if (files.isNotEmpty()) onPicked(files.map { it.path }, false)
            },
            pickAudioFolder = { onPicked ->
                Thread {
                    val log = io.max.paperplay.player.PlayLog
                    try {
                        val pickedDir = NativeDialogs.pickFolder("Choose a music folder")
                        if (pickedDir == null) { log.log("upload", "folder picker closed with no folder"); return@Thread }
                        val scan = scanFolder(pickedDir)
                        log.log("upload", "folder ${pickedDir.path}: ${scan.top.size} songs in it, ${scan.subfolders.size} subfolders with songs")
                        // Back on the window's own thread, where its state is changed.
                        javax.swing.SwingUtilities.invokeLater { onPicked(scan) }
                    } catch (e: Throwable) {
                        log.log("upload", "folder could not be read: ${e::class.simpleName} ${e.message}")
                        // An empty answer makes the page say that nothing was found, instead of staying silent.
                        javax.swing.SwingUtilities.invokeLater { onPicked(io.max.paperplay.ui.app.FolderScan(emptyList(), emptyMap()) { _, ready -> ready(emptyList(), false) }) }
                    }
                }.apply { isDaemon = true; start() }
            },
            pickFolderPath = { onPicked ->
                Thread { NativeDialogs.pickFolder("Choose a music folder")?.let { javax.swing.SwingUtilities.invokeLater { onPicked(it.path) } } }.apply { isDaemon = true; start() }
            },
            authRedirect = LoopbackAuth(),
            authRedirectUri = SPOTIFY_REDIRECT,
            onboarded = { File(dir, "onboarded").exists() },
            setOnboarded = { runCatching { dir.mkdirs(); File(dir, "onboarded").writeText("1") } },
            windowTheme = { dark, bg, text -> WindowsTitleBar.apply(titleBar[0], dark, bg, text) },
        ) }
        // The close button hides the window to the tray and music keeps playing; Quit in the tray menu ends the app.
        var mainVisible by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(true) }
        val mainState = rememberWindowState(width = 1320.dp, height = 840.dp)
        var raise by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(0) }
        androidx.compose.runtime.LaunchedEffect(Unit) { showMain.collect { mainVisible = true; mainState.isMinimized = false; raise++ } }
        // Hidden to the tray or minimized for a while: compact the heap and hand idle pages back to Windows.
        androidx.compose.runtime.LaunchedEffect(mainVisible, mainState.isMinimized) {
            if (!mainVisible || mainState.isMinimized) {
                kotlinx.coroutines.delay(15_000)
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) { MemoryTrim.trim() }
            }
        }
        val trayOk = androidx.compose.ui.window.isTraySupported
        val fullscreen by io.max.paperplay.ui.app.WindowFullscreen.on.collectAsState()
        androidx.compose.runtime.LaunchedEffect(Unit) { io.max.paperplay.ui.app.WindowFullscreen.supported.value = true }
        // Windows uses a borderless window over the monitor (BorderlessFullscreen); elsewhere the toolkit's full screen.
        androidx.compose.runtime.LaunchedEffect(fullscreen) {
            if (!BorderlessFullscreen.supported) mainState.placement = if (fullscreen) androidx.compose.ui.window.WindowPlacement.Fullscreen else androidx.compose.ui.window.WindowPlacement.Floating
        }
        val quit = {
            mainVisible = false
            shutdownServices()
            exitApplication()
        }
        // The tray menu is the app's own themed window (TrayMenuContent) rather than the native Windows menu.
        var trayMenuAt by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<java.awt.Point?>(null) }
        val control = { f: (io.max.paperplay.core.app.PlaybackController) -> Unit -> liveServices?.let { f(it.playback) } }
        if (trayOk) {
            androidx.compose.runtime.DisposableEffect(Unit) {
                val image = javax.imageio.ImageIO.read(Thread.currentThread().contextClassLoader.getResource("icon.png"))
                val trayIcon = java.awt.TrayIcon(image, "Paper Play").apply {
                    isImageAutoSize = true
                    addMouseListener(object : java.awt.event.MouseAdapter() {
                        // Windows delivers a left click reliably only as press and release, not as mouseClicked.
                        override fun mouseReleased(e: java.awt.event.MouseEvent) {
                            if (e.isPopupTrigger || e.button == java.awt.event.MouseEvent.BUTTON3) trayMenuAt = e.point
                            else if (e.button == java.awt.event.MouseEvent.BUTTON1) {
                                javax.swing.SwingUtilities.invokeLater { trayMenuAt = null; mainVisible = true; mainState.isMinimized = false; raise++ }
                            }
                        }
                    })
                    addActionListener { javax.swing.SwingUtilities.invokeLater { mainVisible = true; mainState.isMinimized = false; raise++ } }
                }
                java.awt.SystemTray.getSystemTray().add(trayIcon)
                onDispose { java.awt.SystemTray.getSystemTray().remove(trayIcon) }
            }
        }
        trayMenuAt?.let { at ->
            val screens = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment()
            val gc = screens.screenDevices.map { it.defaultConfiguration }.firstOrNull { it.bounds.contains(at) } ?: screens.defaultScreenDevice.defaultConfiguration
            val b = gc.bounds
            val insets = java.awt.Toolkit.getDefaultToolkit().getScreenInsets(gc)
            val w = io.max.paperplay.ui.app.TrayMenuWidth.value.toInt(); val h = io.max.paperplay.ui.app.TrayMenuHeight.value.toInt()
            val x = (at.x - w / 2).coerceIn(b.x, maxOf(b.x, b.x + b.width - w))
            // Taskbar at the bottom: sit just above it; otherwise start at the click. Windows is asked where the taskbar starts.
            val bottom = minOf(b.y + b.height - insets.bottom, BorderlessFullscreen.workAreaBottom(gc.defaultTransform.scaleY) ?: Int.MAX_VALUE)
            val y = if (at.y > b.y + b.height / 2) bottom - h - 8 else at.y
            androidx.compose.runtime.key(at) {
                androidx.compose.ui.window.DialogWindow(
                    onCloseRequest = { trayMenuAt = null },
                    state = androidx.compose.ui.window.rememberDialogState(
                        position = androidx.compose.ui.window.WindowPosition(x.dp, y.dp),
                        size = androidx.compose.ui.unit.DpSize(io.max.paperplay.ui.app.TrayMenuWidth, io.max.paperplay.ui.app.TrayMenuHeight),
                    ),
                    title = "Paper Play menu", undecorated = true, resizable = false, alwaysOnTop = true,
                    onKeyEvent = {
                        if (it.key == androidx.compose.ui.input.key.Key.Escape && it.type == androidx.compose.ui.input.key.KeyEventType.KeyDown) { trayMenuAt = null; true } else false
                    },
                ) {
                    androidx.compose.runtime.LaunchedEffect(Unit) {
                        WindowsTitleBar.applySurfaceColor(window, DEFAULT_DARK_SURFACE_ARGB)
                        // Closes when the user clicks anywhere else.
                        window.addWindowFocusListener(object : java.awt.event.WindowAdapter() {
                            override fun windowLostFocus(e: java.awt.event.WindowEvent?) { trayMenuAt = null }
                        })
                        WindowsTitleBar.roundCorners(window)
                        window.toFront(); window.requestFocus()
                    }
                    io.max.paperplay.ui.app.TrayMenuContent(
                        onOpen = { mainVisible = true; mainState.isMinimized = false; raise++ },
                        onPlayPause = { control { p -> if (p.nowPlayingStatic.value.isPlaying) p.pause() else p.play() } },
                        onNext = { control { it.next() } },
                        onPrevious = { control { it.previous() } },
                        onMini = { io.max.paperplay.ui.app.DesktopMini.visible.value = !io.max.paperplay.ui.app.DesktopMini.visible.value },
                        onQuit = quit,
                        dismiss = { trayMenuAt = null },
                    )
                }
            }
        }
        // Hidden to the tray the window is removed, not just hidden, so its UI, textures and caches are freed.
        if (mainVisible) Window(
            onCloseRequest = {
                if (trayOk && liveServices?.library?.pref("keep_running") != "false") {
                    mainVisible = false
                    io.max.paperplay.ui.AppForegroundState.isVisible = false
                    io.max.paperplay.ui.AppForegroundState.isForeground = false
                } else quit()
            },
            visible = mainVisible, title = "Paper Play", state = mainState, icon = androidx.compose.ui.res.painterResource("icon.png"),
            onPreviewKeyEvent = {
                if (fullscreen && it.key == androidx.compose.ui.input.key.Key.Escape && it.type == androidx.compose.ui.input.key.KeyEventType.KeyDown) {
                    io.max.paperplay.ui.app.WindowFullscreen.on.value = false; true
                } else false
            },
        ) {
            titleBar[0] = window
            androidx.compose.runtime.LaunchedEffect(window) {
                WindowsTitleBar.applySurfaceColor(window, DEFAULT_DARK_SURFACE_ARGB)
                WindowsTitleBar.reapply(window)
            }
            // Taskbar preview buttons (previous, play or pause, next); a switch in Settings turns them off, from the next start.
            androidx.compose.runtime.LaunchedEffect(window) {
                kotlinx.coroutines.delay(1_500)
                val sv = liveServices ?: run {
                    var waited = 0
                    while (liveServices == null && waited < 30) {
                        kotlinx.coroutines.delay(500)
                        waited++
                    }
                    liveServices
                } ?: return@LaunchedEffect
                if (sv.platform.settings.get("taskbar_buttons") == "off") return@LaunchedEffect
                TaskbarButtons.install(window, ::handleMediaKey)
                try {
                    var lastPlaying: Boolean? = null
                    sv.playback.nowPlayingStatic.collect { np ->
                        if (lastPlaying != np.isPlaying) {
                            lastPlaying = np.isPlaying
                            TaskbarButtons.setPlaying(np.isPlaying)
                        }
                    }
                } finally {
                    TaskbarButtons.release()
                    if (titleBar[0] === window) titleBar[0] = null
                }
            }
            androidx.compose.runtime.DisposableEffect(window, mainVisible, mainState.isMinimized) {
                fun update() {
                    val iconified = (window.extendedState and java.awt.Frame.ICONIFIED) != 0
                    val visible = mainVisible && !mainState.isMinimized && !iconified && window.isShowing
                    val focused = visible && window.isFocused
                    io.max.paperplay.ui.AppForegroundState.isVisible = visible
                    io.max.paperplay.ui.AppForegroundState.isForeground = focused
                }
                update()
                val focusListener = object : java.awt.event.WindowFocusListener {
                    override fun windowGainedFocus(e: java.awt.event.WindowEvent?) = update()
                    override fun windowLostFocus(e: java.awt.event.WindowEvent?) = update()
                }
                val windowListener = object : java.awt.event.WindowAdapter() {
                    override fun windowIconified(e: java.awt.event.WindowEvent?) = update()
                    override fun windowDeiconified(e: java.awt.event.WindowEvent?) = update()
                    override fun windowActivated(e: java.awt.event.WindowEvent?) = update()
                    override fun windowDeactivated(e: java.awt.event.WindowEvent?) = update()
                    override fun windowStateChanged(e: java.awt.event.WindowEvent?) = update()
                }
                window.addWindowFocusListener(focusListener)
                window.addWindowListener(windowListener)
                window.addWindowStateListener(windowListener)
                onDispose {
                    window.removeWindowFocusListener(focusListener)
                    window.removeWindowListener(windowListener)
                    window.removeWindowStateListener(windowListener)
                    io.max.paperplay.ui.AppForegroundState.isForeground = false
                    if (!mainVisible) {
                        io.max.paperplay.ui.AppForegroundState.isVisible = false
                    }
                }
            }
            androidx.compose.runtime.LaunchedEffect(fullscreen) { BorderlessFullscreen.set(window, fullscreen) }
            // Windows only lets a window forward itself when it is not minimised and briefly topmost, so do all three.
            androidx.compose.runtime.LaunchedEffect(mainVisible, raise) {
                if (mainVisible) {
                    kotlinx.coroutines.delay(30)
                    window.extendedState = window.extendedState and java.awt.Frame.ICONIFIED.inv()
                    window.toFront(); window.requestFocus()
                    if (!fullscreen) { window.isAlwaysOnTop = true; window.isAlwaysOnTop = false }
                }
            }
            androidx.compose.runtime.LaunchedEffect(Unit) { installFileDrop(window) }
            androidx.compose.runtime.LaunchedEffect(Unit) { mark(dir, "window first composition") }
            App(env)
        }
        val miniVisible by io.max.paperplay.ui.app.DesktopMini.visible.collectAsState()
        if (miniVisible) MiniWindow()
    }
}

/** Its own composable: it follows what plays, and only it is redrawn for that. */
@androidx.compose.runtime.Composable
private fun androidx.compose.ui.window.ApplicationScope.MiniWindow() {
    // The mini window is as wide as its song text needs (see rememberMiniWidth).
    val targetWidth = io.max.paperplay.ui.app.rememberMiniWidth()
    val animatedWidth by androidx.compose.animation.core.animateDpAsState(
        targetValue = targetWidth,
        animationSpec = io.max.paperplay.ui.theme.desktopMiniResizeSpring(),
        label = "miniWidth",
    )
    val miniState = rememberWindowState(width = targetWidth, height = 110.dp)
    androidx.compose.runtime.LaunchedEffect(animatedWidth) {
        miniState.size = androidx.compose.ui.unit.DpSize(animatedWidth.value.toInt().dp, 110.dp)
    }
    androidx.compose.runtime.DisposableEffect(Unit) {
        io.max.paperplay.ui.AppForegroundState.isMiniVisible = true
        onDispose { io.max.paperplay.ui.AppForegroundState.isMiniVisible = false }
    }
    Window(
        onCloseRequest = { io.max.paperplay.ui.app.DesktopMini.visible.value = false },
        title = "Paper Play mini", state = miniState,
        undecorated = true,
        alwaysOnTop = true, resizable = false, icon = androidx.compose.ui.res.painterResource("icon.png"),
    ) {
        // No title bar: the whole card drags the window, and the close button sits on the card. Windows rounds the corners.
        androidx.compose.runtime.LaunchedEffect(Unit) {
            WindowsTitleBar.applySurfaceColor(window, DEFAULT_DARK_SURFACE_ARGB)
            WindowsTitleBar.roundCorners(window)
        }
        WindowDraggableArea {
            io.max.paperplay.ui.app.DesktopMiniContent(onClose = { io.max.paperplay.ui.app.DesktopMini.visible.value = false })
        }
    }
}
