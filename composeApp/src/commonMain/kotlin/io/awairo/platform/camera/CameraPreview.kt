package io.awairo.platform.camera

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * プラットフォーム固有のカメラプレビューを表示する Composable。
 * Android: CameraX PreviewView / iOS: AVCaptureVideoPreviewLayer
 */
@Composable
expect fun CameraPreview(
    controller: CameraController,
    modifier: Modifier = Modifier
)
