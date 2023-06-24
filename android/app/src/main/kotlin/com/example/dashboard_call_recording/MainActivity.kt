package com.example.dashboard_call_recording

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import java.util.HashMap

class MainActivity: FlutterActivity() {
     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "example.com/cameras"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getCamerasInfo") {
                val cameraInfos = getCameraInfos(context)
                result.success(cameraInfos)
            } else {
                result.notImplemented()
            }
        }
    }


    private fun getCameraInfos(context: Context): ArrayList<HashMap<String, String>> {
        val cameraInfos = ArrayList<HashMap<String, String>>()
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

        try {
            val cameraList = cameraManager.cameraIdList
            for (cameraId in cameraList) {
                var actualCameraInfo = HashMap<String, String>()
                val cameraCharacteristics = cameraManager.getCameraCharacteristics(cameraId)
                val lensFacing = cameraCharacteristics.get(CameraCharacteristics.LENS_FACING)
                val cameraName = cameraCharacteristics.get(CameraCharacteristics.LENS_FACING)
                actualCameraInfo["deviceId"] = cameraId
                actualCameraInfo["cameraName"] = cameraName.toString()
                cameraInfos.add(actualCameraInfo)
            }
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }

        return cameraInfos
    }
}
