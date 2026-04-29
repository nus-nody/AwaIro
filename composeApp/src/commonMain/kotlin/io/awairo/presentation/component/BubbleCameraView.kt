package io.awairo.presentation.component

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import io.awairo.platform.camera.CameraController
import io.awairo.platform.camera.CameraPreview
import io.awairo.platform.camera.bubbleDistortion
import kotlinx.coroutines.launch

@Composable
fun BubbleCameraView(
    controller: CameraController,
    onCaptured: (absoluteImagePath: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val scope = rememberCoroutineScope()
    var isCapturing by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        onDispose { controller.release() }
    }

    Box(
        modifier = modifier.size(260.dp),
        contentAlignment = Alignment.Center
    ) {
        // カメラプレビュー（歪みエフェクト付き）
        CameraPreview(
            controller = controller,
            modifier = Modifier
                .fillMaxSize()
                .bubbleDistortion()
                .pointerInput(Unit) {
                    detectTapGestures {
                        if (!isCapturing) {
                            isCapturing = true
                            scope.launch {
                                val path = controller.capture()
                                isCapturing = false
                                if (path != null) {
                                    onCaptured(path)
                                }
                            }
                        }
                    }
                }
        )

        // ガラスっぽいグラデーションオーバーレイ
        Canvas(modifier = Modifier.fillMaxSize().clip(CircleShape)) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.08f),
                        Color.Transparent,
                        Color.White.copy(alpha = 0.15f)
                    ),
                    center = Offset(size.width * 0.35f, size.height * 0.25f),
                    radius = size.minDimension * 0.6f
                )
            )
        }

        // 撮影中インジケーター
        if (isCapturing) {
            CircularProgressIndicator(
                color = Color.White.copy(alpha = 0.8f),
                modifier = Modifier.size(40.dp)
            )
        }
    }
}

@Composable
fun GrayedOutBubble(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(260.dp)
            .clip(CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawCircle(color = Color.Gray.copy(alpha = 0.3f))
        }
        Text(
            text = "今日の1枚\n撮影済み",
            color = Color.White.copy(alpha = 0.7f)
        )
    }
}
