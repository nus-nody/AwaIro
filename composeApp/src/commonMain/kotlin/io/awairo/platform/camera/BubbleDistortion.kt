package io.awairo.platform.camera

import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

/**
 * 泡の歪みエフェクトを適用する Modifier。
 * 円形クリップ + 中央部を拡大することで球面レンズ越しに見るような視覚効果を再現する。
 */
fun Modifier.bubbleDistortion(): Modifier = this
    .shadow(elevation = 12.dp, shape = CircleShape, clip = false)
    .graphicsLayer {
        // 内部を少し拡大して歪み感を演出
        scaleX = 1.18f
        scaleY = 1.18f
    }
    .clip(CircleShape)
