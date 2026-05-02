package io.awairo.presentation.component

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.ImageLoader
import coil3.compose.AsyncImage
import coil3.compose.LocalPlatformContext
import io.awairo.presentation.theme.LocalSkyTheme
import kotlin.math.abs
import kotlin.time.Duration

/**
 * 1 枚の写真を泡で表現するアイテム。
 * 現像済み: 中に写真を表示。未現像: 透明で「あと○時間」を表示。
 *
 * @param photoId 写真 ID（位置・サイズの決定的シードに使う）
 * @param imagePath 現像済み時のローカル画像パス
 * @param dateLabel 表示する日付ラベル（例 "05/02"）
 * @param isDeveloped 現像済みフラグ
 * @param remaining 未現像時の残り時間
 * @param indexInList LazyColumn 内の index（フローティング位相のずらしに使う）
 * @param onTap タップ時のコールバック
 */
@Composable
fun BubbleGalleryItem(
    photoId: String,
    imagePath: String?,
    dateLabel: String,
    isDeveloped: Boolean,
    remaining: Duration,
    indexInList: Int,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val theme = LocalSkyTheme.current

    // 写真 ID から決定的にサイズと水平オフセットを決める（毎回同じ）
    val seed = photoId.hashCode()
    val sizes = listOf(180.dp, 145.dp, 115.dp, 95.dp)
    val sizeDp: Dp = sizes[abs(seed) % sizes.size]
    val xOffsetDp = (((abs(seed) / sizes.size) % 90) - 45).dp

    // 浮遊アニメ（位置と微スケール）
    val transition = rememberInfiniteTransition(label = "bubble-$photoId")
    val phaseSec = 5 + (abs(seed) % 4)
    val translateY by transition.animateFloat(
        initialValue = 0f,
        targetValue = -10f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = phaseSec * 1000),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "translateY",
    )
    val scaleAnim by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1.04f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = phaseSec * 1000),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "scaleAnim",
    )

    Box(
        modifier = modifier
            .padding(horizontal = 8.dp)
            .graphicsLayer {
                translationX = xOffsetDp.toPx()
                translationY = translateY
                scaleX = scaleAnim
                scaleY = scaleAnim
            }
            .size(sizeDp)
            .clip(CircleShape)
            .clickable(onClick = onTap),
    ) {
        // 写真 or 透明背景
        if (isDeveloped && imagePath != null) {
            val ctx = LocalPlatformContext.current
            val loader = remember(ctx) { ImageLoader(ctx) }
            AsyncImage(
                model = imagePath,
                imageLoader = loader,
                contentDescription = null,
                modifier = Modifier.fillMaxSize().clip(CircleShape),
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(if (theme.isDark) Color(0x1A2A3A60) else Color(0x14A0AAC8)),
                contentAlignment = Alignment.Center,
            ) {
                UndevelopedLabel(remaining = remaining, isDark = theme.isDark)
            }
        }

        // 虹色薄膜（半透明グラデーション）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0x1FFF78C8),
                            Color(0x1964C8FF),
                            Color(0x14B4FFA0),
                            Color(0x12FFC864),
                            Color(0x19C878FF),
                        ),
                    )
                ),
        )

        // 縁の光（リング）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .border(
                    width = 1.dp,
                    color = if (theme.isDark) Color(0x33FFFFFF) else Color(0x80FFFFFF),
                    shape = CircleShape,
                ),
        )

        // ハイライト（左上）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(Color(0x59FFFFFF), Color(0x00FFFFFF)),
                        center = Offset(x = sizeDp.value * 0.32f, y = sizeDp.value * 0.22f),
                        radius = sizeDp.value * 0.4f,
                    )
                ),
        )

        // 日付ラベル（現像済みのみ）
        if (isDeveloped) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.BottomCenter,
            ) {
                Text(
                    text = dateLabel,
                    fontSize = 10.sp,
                    color = Color(0xB3FFFFFF),
                    modifier = Modifier.padding(bottom = (sizeDp.value * 0.13f).dp),
                )
            }
        }
    }
}

@Composable
private fun UndevelopedLabel(remaining: Duration, isDark: Boolean) {
    val labelColor = if (isDark) Color(0x709BAFEB) else Color(0x705060A0)
    val timeColor = if (isDark) Color(0x4782A5E6) else Color(0x4D5060A0)
    val hours = remaining.inWholeHours
    val timeText = if (hours <= 0) "まもなく" else "あと ${hours}h"
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = "現像中", fontSize = 9.sp, color = labelColor)
        Text(text = timeText, fontSize = 13.sp, color = timeColor)
    }
}
