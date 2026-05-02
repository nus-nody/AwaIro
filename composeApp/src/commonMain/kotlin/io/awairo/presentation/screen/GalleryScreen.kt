package io.awairo.presentation.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.awairo.domain.usecase.DevelopedPhoto
import io.awairo.presentation.component.BottomActionBar
import io.awairo.presentation.component.BubbleGalleryItem
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.viewmodel.GalleryViewModel
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun GalleryScreen(
    onPhotoTap: (photoId: String) -> Unit,
    onBackToHome: () -> Unit,
    onOpenMenu: () -> Unit,
    viewModel: GalleryViewModel = koinViewModel(),
) {
    val photos by viewModel.photos.collectAsState()
    val theme = LocalSkyTheme.current

    LaunchedEffect(Unit) { viewModel.refresh() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(theme.backgroundTop, theme.backgroundBottom))),
    ) {
        if (photos.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "まだ泡がありません", color = theme.textSecondary, fontSize = 14.sp)
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 24.dp, bottom = 80.dp),
            ) {
                item {
                    Text(
                        text = "AWA IRO",
                        color = theme.textSecondary,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 16.dp),
                    )
                }
                itemsIndexed(items = photos) { index, devPhoto ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        BubbleGalleryItem(
                            photoId = devPhoto.id,
                            imagePath = devPhoto.photo.imagePath,
                            dateLabel = formatDate(devPhoto),
                            isDeveloped = devPhoto.isDeveloped,
                            remaining = devPhoto.remaining,
                            indexInList = index,
                            onTap = {
                                if (devPhoto.isDeveloped) onPhotoTap(devPhoto.id)
                            },
                        )
                    }
                }
                item { Spacer(Modifier.height(40.dp)) }
            }
        }

        BottomActionBar(
            leftLabel = "ホーム",
            leftIcon = "◯",
            onLeftClick = onBackToHome,
            rightLabel = "メニュー",
            rightIcon = "⊙",
            onRightClick = onOpenMenu,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

private fun formatDate(devPhoto: DevelopedPhoto): String {
    val tz = TimeZone.currentSystemDefault()
    val dt = devPhoto.photo.capturedAt.toLocalDateTime(tz)
    val mm = dt.monthNumber.toString().padStart(2, '0')
    val dd = dt.dayOfMonth.toString().padStart(2, '0')
    return "$mm/$dd"
}
