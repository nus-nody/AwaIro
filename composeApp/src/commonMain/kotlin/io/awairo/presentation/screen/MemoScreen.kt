package io.awairo.presentation.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import io.awairo.platform.deletePhotoFile
import io.awairo.presentation.viewmodel.MemoViewModel
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun MemoScreen(
    absoluteImagePath: String,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    viewModel: MemoViewModel = koinViewModel()
) {
    val saveState by viewModel.saveState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var memo by remember { mutableStateOf("") }

    // 保存成功 → onSaved を呼ぶ
    LaunchedEffect(saveState) {
        when (val state = saveState) {
            is MemoViewModel.SaveState.Success -> {
                viewModel.resetState()
                onSaved()
            }
            is MemoViewModel.SaveState.Error -> {
                // DB保存失敗 → 画像ファイルを削除してクリーンアップ
                deletePhotoFile(absoluteImagePath)
                snackbarHostState.showSnackbar(state.message)
                viewModel.resetState()
            }
            else -> Unit
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // 撮影した写真のサムネイル
            AsyncImage(
                model = absoluteImagePath,
                contentDescription = "撮影した写真",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(200.dp)
                    .clip(RoundedCornerShape(12.dp))
            )

            Spacer(modifier = Modifier.height(24.dp))

            // メモ入力
            OutlinedTextField(
                value = memo,
                onValueChange = { memo = it },
                label = { Text("ひとこと（任意）") },
                modifier = Modifier.fillMaxWidth(),
                maxLines = 3
            )

            Spacer(modifier = Modifier.height(24.dp))

            // 残すボタン
            Button(
                onClick = { viewModel.save(absoluteImagePath, memo) },
                enabled = saveState !is MemoViewModel.SaveState.Saving,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = if (saveState is MemoViewModel.SaveState.Saving) "保存中..." else "残す"
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // キャンセル → 画像ファイルを削除してからホームに戻る
            TextButton(onClick = {
                deletePhotoFile(absoluteImagePath)
                onCancel()
            }) {
                Text("やめる")
            }
        }
    }
}
