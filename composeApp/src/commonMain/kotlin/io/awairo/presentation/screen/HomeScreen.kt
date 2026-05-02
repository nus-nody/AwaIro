package io.awairo.presentation.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import io.awairo.platform.camera.CameraController
import io.awairo.presentation.component.BottomActionBar
import io.awairo.presentation.component.BubbleCameraView
import io.awairo.presentation.component.GrayedOutBubble
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.viewmodel.HomeViewModel
import org.koin.compose.koinInject
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun HomeScreen(
    onPhotoCaptured: (absoluteImagePath: String) -> Unit,
    onOpenGallery: () -> Unit = {},   // default は Task 15 で App.kt が実コールバックを渡すまでの暫定値
    onOpenMenu: () -> Unit = {},
    viewModel: HomeViewModel = koinViewModel()
) {
    val isTodayPhotoTaken by viewModel.isTodayPhotoTaken.collectAsState()
    val cameraController = koinInject<CameraController>()
    val theme = LocalSkyTheme.current

    LaunchedEffect(Unit) { viewModel.refreshTodayStatus() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(theme.backgroundTop, theme.backgroundBottom))),
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            if (isTodayPhotoTaken) {
                GrayedOutBubble()
            } else if (cameraController.hasPermission()) {
                BubbleCameraView(
                    controller = cameraController,
                    onCaptured = { path ->
                        viewModel.refreshTodayStatus()
                        onPhotoCaptured(path)
                    },
                )
            } else {
                CameraPermissionUI(cameraController = cameraController)
            }
        }

        BottomActionBar(
            leftLabel = "泡たち",
            leftIcon = "○",
            onLeftClick = onOpenGallery,
            rightLabel = "メニュー",
            rightIcon = "⊙",
            onRightClick = onOpenMenu,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun CameraPermissionUI(cameraController: CameraController) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(24.dp)
    ) {
        Text(
            text = "カメラへのアクセスが必要です",
            style = MaterialTheme.typography.titleMedium
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "設定アプリからカメラの使用を許可してください",
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
