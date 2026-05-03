package io.awairo.presentation.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.ImageLoader
import coil3.compose.AsyncImage
import io.awairo.presentation.theme.LocalSkyTheme
import org.koin.compose.koinInject
import io.awairo.presentation.viewmodel.PhotoDetailViewModel
import kotlinx.coroutines.launch
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun PhotoDetailScreen(
    initialPhotoId: String,
    onBack: () -> Unit,
    onShareClick: () -> Unit,
    viewModel: PhotoDetailViewModel = koinViewModel(),
) {
    val theme = LocalSkyTheme.current
    val photos by viewModel.developedPhotos.collectAsState()
    var initialIndex by remember { mutableStateOf(0) }
    var initialised by remember { mutableStateOf(false) }

    LaunchedEffect(initialPhotoId) {
        initialIndex = viewModel.loadDevelopedAndFindIndex(initialPhotoId)
        initialised = true
    }

    if (!initialised || photos.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize().background(theme.backgroundBottom),
            contentAlignment = Alignment.Center,
        ) {
            Text("読み込み中…", color = theme.textSecondary)
        }
        return
    }

    val pagerState = rememberPagerState(initialPage = initialIndex) { photos.size }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(theme.backgroundTop, theme.backgroundBottom))),
    ) {
        HorizontalPager(state = pagerState) { pageIndex ->
            val devPhoto = photos[pageIndex]
            DetailPage(
                imagePath = devPhoto.photo.imagePath,
                memo = devPhoto.photo.memo,
                dateLabel = formatDateTime(devPhoto.photo.capturedAt),
                areaLabel = devPhoto.photo.areaLabel,
                onMemoSave = { viewModel.updateMemo(devPhoto.id, it) },
            )
        }

        // 上部ヘッダ（戻る・シェア）
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(onClick = onBack) {
                Text("← 戻る", color = theme.textPrimary)
            }
            TextButton(onClick = onShareClick) {
                Text("⤴ シェア", color = theme.textSecondary)
            }
        }
    }
}

@Composable
private fun DetailPage(
    imagePath: String,
    memo: String,
    dateLabel: String,
    areaLabel: String,
    onMemoSave: (String) -> Unit,
) {
    val theme = LocalSkyTheme.current
    var editing by remember { mutableStateOf(false) }
    var draft by remember(memo) { mutableStateOf(memo) }
    val loader = koinInject<ImageLoader>()
    val scope = rememberCoroutineScope()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 64.dp, start = 24.dp, end = 24.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            AsyncImage(
                model = imagePath,
                imageLoader = loader,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .clip(RoundedCornerShape(20.dp)),
            )
        }
        item {
            Text(text = dateLabel, color = theme.textSecondary, fontSize = 12.sp)
            if (areaLabel.isNotBlank()) {
                Text(text = areaLabel, color = theme.textSecondary, fontSize = 12.sp)
            }
        }
        item {
            if (editing) {
                Column {
                    OutlinedTextField(
                        value = draft,
                        onValueChange = { if (it.length <= 100) draft = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("メモ", color = theme.textSecondary) },
                    )
                    Row(modifier = Modifier.padding(top = 8.dp)) {
                        TextButton(onClick = { editing = false; draft = memo }) {
                            Text("キャンセル", color = theme.textSecondary)
                        }
                        Spacer(Modifier.weight(1f))
                        TextButton(onClick = {
                            scope.launch {
                                onMemoSave(draft)
                                editing = false
                            }
                        }) {
                            Text("保存", color = theme.textPrimary)
                        }
                    }
                }
            } else {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { editing = true },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = if (memo.isBlank()) "メモなし" else memo,
                        color = if (memo.isBlank()) theme.textSecondary else theme.textPrimary,
                        modifier = Modifier.padding(end = 8.dp),
                        fontSize = 14.sp,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = "✎",
                        color = theme.textSecondary,
                        fontSize = 16.sp,
                    )
                }
            }
        }
    }
}

private fun formatDateTime(instant: Instant): String {
    val tz = TimeZone.currentSystemDefault()
    val dt = instant.toLocalDateTime(tz)
    val mm = dt.monthNumber.toString().padStart(2, '0')
    val dd = dt.dayOfMonth.toString().padStart(2, '0')
    val hh = dt.hour.toString().padStart(2, '0')
    val mi = dt.minute.toString().padStart(2, '0')
    return "${dt.year} / $mm / $dd  $hh:$mi"
}
