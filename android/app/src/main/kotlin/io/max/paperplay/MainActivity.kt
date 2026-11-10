package io.max.paperplay

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaRouter2
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var pendingOpen: String? = null

    private var backgroundChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // A tap that started the app from nothing.
        intent?.getStringExtra(OPEN_EXTRA)?.let { pendingOpen = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A tap while the app is running: told to Flutter now, since it won't be asked.
        intent.getStringExtra(OPEN_EXTRA)?.let {
            pendingOpen = it
            backgroundChannel?.invokeMethod("open", it)
        }
    }

    private var channel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    private val audio get() = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = announceSoon()
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = announceSoon()
    }

    // A new device takes a moment to become the route it's about to be.
    private fun announceSoon() {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ channel?.invokeMethod("changed", currentRoute()) }, 700)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "teleplayer/audio_output").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(currentRoute())
                    "openSwitcher" -> result.success(openSwitcher())
                    "openBluetooth" -> result.success(openSettings(Settings.ACTION_BLUETOOTH_SETTINGS))
                    "requestAudioAccess" -> requestAudioAccess(result)
                    else -> result.notImplemented()
                }
            }
        }
        backgroundChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "teleplayer/background")
        backgroundChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(startKeepAlive())
                "stop" -> result.success(stopService(Intent(this, KeepAliveService::class.java)))
                "batteryExempt" -> result.success(
                    (getSystemService(Context.POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(packageName),
                )
                "requestBatteryExemption" -> result.success(
                    openSettings(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, "package:$packageName"),
                )
                "openAppSettings" -> result.success(
                    openSettings(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, "package:$packageName"),
                )
                "requestNotifications" -> requestNotifications(result)
                "saveFile" -> saveFile(
                    call.argument<String>("name") ?: "backup.zip",
                    call.argument<String>("path") ?: "",
                    result,
                )
                "charging" -> result.success(
                    (getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager).isCharging,
                )
                "copyProgress" -> {
                    KeepAliveService.copyProgress(
                        this,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "",
                        call.argument<Int>("progress"),
                        call.argument<Int>("max"),
                        call.argument<String>("open") ?: "",
                    )
                    result.success(true)
                }
                // What a tapped notification asked to open, once.
                "takeOpen" -> {
                    result.success(pendingOpen)
                    pendingOpen = null
                }
                "update" -> {
                    KeepAliveService.update(
                        this,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "",
                        call.argument<Int>("progress"),
                        call.argument<Int>("max"),
                        call.argument<Boolean>("indeterminate") ?: false,
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        audio.registerAudioDeviceCallback(deviceCallback, handler)
    }

    // Android refuses to start one from the background, which is the case when the
    // app was woken by a media button. It's started again next time it's opened.
    private fun startKeepAlive(): Boolean = try {
        startForegroundService(Intent(this, KeepAliveService::class.java))
        true
    } catch (_: Exception) {
        false
    }

    private var saveResult: MethodChannel.Result? = null
    private var savePath: String? = null

    /**
     * Lets the person pick where a file goes, then copies it there from disk in pieces. The file
     * never passes through the Flutter channel: a 300 MB backup sent that way needs a 300 MB
     * array here, more than the app's heap allows, and crashed it.
     */
    private fun saveFile(name: String, path: String, result: MethodChannel.Result) {
        if (path.isEmpty() || !java.io.File(path).exists()) {
            result.success(false)
            return
        }
        saveResult?.success(false)
        saveResult = result
        savePath = path
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/zip")
            .putExtra(Intent.EXTRA_TITLE, name)
        startActivityForResult(intent, SAVE_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_REQUEST) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = saveResult
        val path = savePath
        saveResult = null
        savePath = null
        val uri = data?.data
        if (result == null || path == null || resultCode != RESULT_OK || uri == null) {
            result?.success(false)
            return
        }
        Thread {
            val ok = try {
                java.io.File(path).inputStream().use { input ->
                    contentResolver.openOutputStream(uri, "w")!!.use { output -> input.copyTo(output, 1 shl 20) }
                }
                true
            } catch (_: Exception) {
                false
            }
            handler.post { result.success(ok) }
        }.start()
    }

    private var notifyResult: MethodChannel.Result? = null

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        notifyResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFY_REQUEST)
    }

    override fun onResume() {
        super.onResume()
        // The system's switcher gives no callback when it changes the route.
        announceSoon()
    }

    override fun onDestroy() {
        audio.unregisterAudioDeviceCallback(deviceCallback)
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun currentRoute(): Map<String, String?> {
        val device = activeDevice()
        val kind = device?.let { kindOf(it.type) } ?: "speaker"
        return mapOf(
            "kind" to kind,
            // A built-in speaker's product name is only the phone's model.
            "name" to if (kind == "speaker") null else device?.productName?.toString(),
        )
    }

    private fun activeDevice(): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val media = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()
            audio.getAudioDevicesForAttributes(media).firstOrNull()?.let { active ->
                return audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .firstOrNull { it.type == active.type && it.address == active.address }
            }
        }
        // Older versions can't say, but Android prefers these in this order.
        return audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).minByOrNull {
            when (kindOf(it.type)) {
                "bluetooth" -> 0
                "wired" -> 1
                "usb" -> 2
                "other" -> 3
                else -> 4
            }
        }
    }

    private fun kindOf(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_BLE_SPEAKER,
        AudioDeviceInfo.TYPE_BLE_BROADCAST -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired"
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "speaker"
        else -> "other"
    }

    private var accessResult: MethodChannel.Result? = null

    private fun requestAudioAccess(result: MethodChannel.Result) {
        val permission = if (Build.VERSION.SDK_INT >= 33) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        accessResult = result
        requestPermissions(arrayOf(permission), ACCESS_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            ACCESS_REQUEST -> {
                accessResult?.success(granted)
                accessResult = null
            }
            NOTIFY_REQUEST -> {
                notifyResult?.success(granted)
                notifyResult = null
            }
        }
    }

    companion object {
        const val OPEN_EXTRA = "open"
        const val ACCESS_REQUEST = 4711
        const val NOTIFY_REQUEST = 4713
        const val SAVE_REQUEST = 4714
    }

    private fun openSwitcher(): Boolean {
        if (Build.VERSION.SDK_INT >= 34 && MediaRouter2.getInstance(this).showSystemOutputSwitcher()) {
            return true
        }
        return openSettings(Settings.ACTION_BLUETOOTH_SETTINGS)
    }

    private fun openSettings(action: String, uri: String? = null): Boolean = try {
        startActivity(Intent(action).apply { if (uri != null) data = Uri.parse(uri) })
        true
    } catch (_: Exception) {
        false
    }
}
