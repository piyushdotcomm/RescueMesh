package com.rescuemesh.rescuemesh

import android.content.Context
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val FLASHLIGHT_CHANNEL = "com.rescuemesh/flashlight"
    private val VIBRATE_CHANNEL = "com.rescuemesh/vibrate"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var vibrator: Vibrator? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager

        // Vibrate
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val mgr = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            mgr.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        // Flashlight
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLASHLIGHT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setFlashlight") {
                    toggleFlash(call.arguments as Boolean)
                    result.success(null)
                } else result.notImplemented()
            }

        // Vibrate
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        val repeat = call.argument<Boolean>("repeat") ?: false
                        val durationMs = (call.argument<Int>("duration") ?: 400).toLong()
                        if (repeat) {
                            val pattern = longArrayOf(0, 200, 100, 200, 100, 200, 100, 200, 100, 600)
                            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                        } else {
                            vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
                        }
                        result.success(null)
                    }
                    "cancel" -> {
                        vibrator?.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun toggleFlash(on: Boolean) {
        try {
            if (cameraId == null) cameraId = cameraManager?.cameraIdList?.firstOrNull()
            cameraId?.let { id ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    cameraManager?.setTorchMode(id, on)
            }
        } catch (_: Exception) {}
    }
}
