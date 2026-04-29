package io.awairo.platform.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.core.content.ContextCompat
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume

actual class CameraController(private val context: Context) {

    // CameraPreview.android.kt から参照される
    internal val imageCapture: ImageCapture = ImageCapture.Builder().build()

    private val photosDir: File by lazy {
        File(context.filesDir, "photos").also { it.mkdirs() }
    }

    actual fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

    actual suspend fun capture(): String? = suspendCancellableCoroutine { cont ->
        val file = File(photosDir, "${UUID.randomUUID()}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(file).build()

        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    cont.resume(file.absolutePath)
                }
                override fun onError(exception: ImageCaptureException) {
                    cont.resume(null)
                }
            }
        )
    }

    actual fun release() {
        // CameraX のバインドは CameraPreview コンポーザブル内で管理するため、ここでは何もしない
    }
}
