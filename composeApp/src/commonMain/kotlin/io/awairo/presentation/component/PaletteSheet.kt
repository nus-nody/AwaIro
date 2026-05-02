package io.awairo.presentation.component

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.theme.resolveSkyTheme

/**
 * 下からスライドアップするパレット選択シート。
 * メニューボタンタップで visible を切り替える。
 */
@Composable
fun PaletteSheet(
    visible: Boolean,
    currentPalette: SkyPalette,
    currentMode: ThemeMode,
    onPaletteClick: (SkyPalette) -> Unit,
    onModeClick: (ThemeMode) -> Unit,
    modifier: Modifier = Modifier,
) {
    val theme = LocalSkyTheme.current
    val panelBg = if (theme.isDark) Color(0xEE060614) else Color(0xF6F8F5F0)

    AnimatedVisibility(
        visible = visible,
        enter = expandVertically() + fadeIn(),
        exit = shrinkVertically() + fadeOut(),
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(panelBg)
                .padding(horizontal = 20.dp, vertical = 14.dp),
        ) {
            Text(
                text = "空の色",
                fontSize = 10.sp,
                color = theme.textSecondary,
                modifier = Modifier.padding(bottom = 10.dp),
            )

            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 14.dp),
            ) {
                SkyPalette.entries.forEach { p ->
                    PaletteSwatch(
                        palette = p,
                        isDark = theme.isDark,
                        selected = p == currentPalette,
                        onClick = { onPaletteClick(p) },
                    )
                }
            }

            Text(
                text = "表示モード",
                fontSize = 10.sp,
                color = theme.textSecondary,
                modifier = Modifier.padding(bottom = 6.dp),
            )

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ThemeMode.entries.forEach { m ->
                    ModeButton(
                        label = when (m) {
                            ThemeMode.SYSTEM -> "システム"
                            ThemeMode.DARK -> "ダーク"
                            ThemeMode.LIGHT -> "ライト"
                        },
                        selected = m == currentMode,
                        textColor = theme.textPrimary,
                        onClick = { onModeClick(m) },
                    )
                }
            }
        }
    }
}

@Composable
private fun PaletteSwatch(
    palette: SkyPalette,
    isDark: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val sample = resolveSkyTheme(palette, ThemeMode.SYSTEM, isSystemDark = isDark)
    val brush = Brush.radialGradient(
        colors = listOf(sample.gradientA, sample.backgroundTop),
    )
    val ringColor = if (selected) Color(0xCCFFFFFF) else Color.Transparent
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(brush)
                .border(width = 2.dp, color = ringColor, shape = CircleShape)
                .clickable(onClick = onClick),
        )
        Text(
            text = palette.displayName,
            fontSize = 9.sp,
            color = LocalSkyTheme.current.textSecondary,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun ModeButton(
    label: String,
    selected: Boolean,
    textColor: Color,
    onClick: () -> Unit,
) {
    val borderColor = if (selected) textColor.copy(alpha = 0.6f) else textColor.copy(alpha = 0.18f)
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, borderColor, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text(text = label, fontSize = 11.sp, color = textColor)
    }
}
