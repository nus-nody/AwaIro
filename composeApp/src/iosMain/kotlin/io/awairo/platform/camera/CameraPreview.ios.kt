package io.awairo.platform.camera

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.UIKitView
import kotlinx.cinterop.ExperimentalForeignApi
import platform.AVFoundation.AVCaptureDevice
import platform.AVFoundation.AVCaptureVideoPreviewLayer
import platform.AVFoundation.AVLayerVideoGravityResizeAspectFill
import platform.AVFoundation.AVMediaTypeVideo
import platform.AVFoundation.requestAccessForMediaType
import platform.QuartzCore.CATransaction
import platform.QuartzCore.kCATransactionDisableActions
import platform.UIKit.UIView

@OptIn(ExperimentalForeignApi::class)
@Composable
actual fun CameraPreview(
    controller: CameraController,
    modifier: Modifier
) {
    // iOS は初回アクセス時に自動でパーミッションダイアログを表示する
    LaunchedEffect(Unit) {
        if (!controller.hasPermission()) {
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { _ -> }
        }
    }

    DisposableEffect(Unit) {
        controller.session.startRunning()
        onDispose {
            controller.session.stopRunning()
        }
    }

    UIKitView(
        factory = {
            val view = UIView()
            val previewLayer = AVCaptureVideoPreviewLayer(session = controller.session)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            CATransaction.begin()
            CATransaction.setValue(true, forKey = kCATransactionDisableActions)
            view.layer.addSublayer(previewLayer)
            CATransaction.commit()
            // previewLayer のサイズは update で調整する
            view
        },
        update = { view ->
            // UIKitView がリサイズされるたびに previewLayer のフレームを更新
            // filterIsInstance is unreliable on ObjC-bridged NSArray — use as? for isKindOfClass: semantics
            val previewLayer = view.layer.sublayers
                ?.mapNotNull { it as? AVCaptureVideoPreviewLayer }
                ?.firstOrNull()
            CATransaction.begin()
            CATransaction.setValue(true, forKey = kCATransactionDisableActions)
            previewLayer?.frame = view.bounds
            CATransaction.commit()
        },
        modifier = modifier
    )
}
