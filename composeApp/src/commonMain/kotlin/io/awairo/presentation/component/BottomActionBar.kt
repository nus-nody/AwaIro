package io.awairo.presentation.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.awairo.presentation.theme.LocalSkyTheme

/**
 * 画面下部の左右アクションボタンバー。HomeScreen と GalleryScreen で共用。
 */
@Composable
fun BottomActionBar(
    leftLabel: String,
    leftIcon: String,
    onLeftClick: () -> Unit,
    rightLabel: String,
    rightIcon: String,
    onRightClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val theme = LocalSkyTheme.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(72.dp)
            .padding(horizontal = 32.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        ActionButton(label = leftLabel, icon = leftIcon, onClick = onLeftClick, color = theme.textPrimary)
        ActionButton(label = rightLabel, icon = rightIcon, onClick = onRightClick, color = theme.textPrimary)
    }
}

@Composable
private fun ActionButton(label: String, icon: String, onClick: () -> Unit, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(CircleShape)
            .clickable(onClick = onClick)
            .padding(8.dp),
    ) {
        Box(
            modifier = Modifier.size(32.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = icon, fontSize = 20.sp, color = color)
        }
        Text(text = label, fontSize = 10.sp, color = color.copy(alpha = 0.7f))
    }
}
