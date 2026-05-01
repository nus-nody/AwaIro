package io.awairo.platform.camera

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.suspendCancellableCoroutine
import platform.AVFoundation.AVAuthorizationStatusAuthorized
import platform.AVFoundation.AVCaptureDevice
import platform.AVFoundation.AVCaptureDeviceInput
import platform.AVFoundation.AVCaptureInput
import platform.AVFoundation.AVCaptureOutput
import platform.AVFoundation.AVCapturePhoto
import platform.AVFoundation.AVCapturePhotoCaptureDelegateProtocol
import platform.AVFoundation.AVCapturePhotoOutput
import platform.AVFoundation.AVCapturePhotoSettings
import platform.AVFoundation.AVCaptureSession
import platform.AVFoundation.AVCaptureSessionPresetPhoto
import platform.AVFoundation.AVMediaTypeVideo
import platform.AVFoundation.AVVideoCodecKey
import platform.AVFoundation.AVVideoCodecTypeJPEG
import platform.AVFoundation.authorizationStatusForMediaType
import platform.AVFoundation.fileDataRepresentation
import platform.Foundation.NSApplicationSupportDirectory
import platform.Foundation.NSError
import platform.Foundation.NSFileManager
import platform.darwin.NSObject
import platform.Foundation.NSSearchPathForDirectoriesInDomains
import platform.Foundation.NSUserDomainMask
import platform.Foundation.NSUUID
import platform.Foundation.writeToFile
import kotlin.coroutines.resume

@OptIn(ExperimentalForeignApi::class)
actual class CameraController {

    // CameraPreview.ios.kt から参照される
    internal val session: AVCaptureSession = AVCaptureSession()
    private val photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    private val photosDir: String by lazy { setupPhotosDir() }

    init {
        setupSession()
    }

    private fun setupSession() {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto

        val device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if (device != null) {
            val input = AVCaptureDeviceInput.deviceInputWithDevice(device, null)
            if (input != null && session.canAddInput(input)) {
                session.addInput(input)
            }
        }
        if (session.canAddOutput(photoOutput)) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    private fun setupPhotosDir(): String {
        val paths = NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory,
            NSUserDomainMask,
            true
        )
        val appSupport = paths.firstOrNull() as? String ?: ""
        val dir = "$appSupport/photos"
        NSFileManager.defaultManager.createDirectoryAtPath(
            dir,
            withIntermediateDirectories = true,
            attributes = null,
            error = null
        )
        return dir
    }

    actual fun hasPermission(): Boolean =
        AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) ==
                AVAuthorizationStatusAuthorized

    actual suspend fun capture(): String? = suspendCancellableCoroutine { cont ->
        val settings = AVCapturePhotoSettings.photoSettingsWithFormat(
            mapOf(AVVideoCodecKey to AVVideoCodecTypeJPEG)
        )
        val filename = "${NSUUID().UUIDString}.jpg"
        val filePath = "$photosDir/$filename"

        photoOutput.capturePhotoWithSettings(
            settings,
            delegate = object : NSObject(), AVCapturePhotoCaptureDelegateProtocol {
                override fun captureOutput(
                    output: AVCapturePhotoOutput,
                    didFinishProcessingPhoto: AVCapturePhoto,
                    error: NSError?
                ) {
                    if (error != null) {
                        cont.resume(null)
                        return
                    }
                    val data = didFinishProcessingPhoto.fileDataRepresentation() ?: run {
                        cont.resume(null)
                        return
                    }
                    val saved = data.writeToFile(filePath, atomically = true)
                    cont.resume(if (saved) filePath else null)
                }
            }
        )
    }

    actual fun release() {
        if (session.running) session.stopRunning()
        session.beginConfiguration()
        session.inputs.toList().forEach { session.removeInput(it as AVCaptureInput) }
        session.outputs.toList().forEach { session.removeOutput(it as AVCaptureOutput) }
        session.commitConfiguration()
    }
}
