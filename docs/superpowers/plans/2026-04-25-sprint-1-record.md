# Sprint 1 — Record（泡カメラ） Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ホーム画面の「泡」にカメラプレビューを表示し、タップで撮影→メモ入力→DBに保存する1日1枚の記録体験を実装する。

**Architecture:** `expect class CameraController` + `expect fun CameraPreview` で Android（CameraX）/ iOS（AVFoundation）のカメラを抽象化。ナビゲーションは外部ライブラリなしの `sealed class Screen` で管理。歪みエフェクトは commonMain の純粋 Compose で実装（`clip(CircleShape)` + `graphicsLayer` スケール）。

**Tech Stack:** CameraX 1.4.1（Android）、AVFoundation（iOS）、Coil3 3.1.0（画像表示）、Koin 4.0 ViewModelScope、kotlinx-datetime、kotlinx-coroutines-test（テスト）

---

## ベースライン確認（実装開始前に必ず実行）

```bash
cd /Users/nodayouta/Documents/code/AwaIro
./gradlew :composeApp:assembleDebug
# → BUILD SUCCESSFUL を確認してから Task 1 へ
```

**読むべきファイル:**
- `docs/superpowers/specs/2026-04-25-sprint-1-record-design.md` — 設計書
- `composeApp/src/androidMain/kotlin/io/awairo/data/local/DatabaseFactory.android.kt` — expect/actual パターンの参考
- `composeApp/src/iosMain/kotlin/io/awairo/data/local/DatabaseFactory.ios.kt` — iOS actual の参考

---

## Task 1: Gradle 依存関係の追加

**Files:**
- Modify: `gradle/libs.versions.toml`
- Modify: `composeApp/build.gradle.kts`

- [ ] **Step 1: versions.toml に CameraX + Coil3 + coroutines-test を追加**

```toml
# gradle/libs.versions.toml の [versions] セクションに追加
camerax = "1.4.1"
coil = "3.1.0"
kotlinx-coroutines-test = "1.9.0"

# [libraries] セクションに追加
androidx-camera-camera2 = { module = "androidx.camera:camera-camera2", version.ref = "camerax" }
androidx-camera-lifecycle = { module = "androidx.camera:camera-lifecycle", version.ref = "camerax" }
androidx-camera-view = { module = "androidx.camera:camera-view", version.ref = "camerax" }
coil-compose = { module = "io.coil-kt.coil3:coil-compose", version.ref = "coil" }
coil-core = { module = "io.coil-kt.coil3:coil-core", version.ref = "coil" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "kotlinx-coroutines-test" }
```

- [ ] **Step 2: build.gradle.kts に依存関係を追加**

`composeApp/build.gradle.kts` の `sourceSets { ... }` ブロックを以下に更新:

```kotlin
sourceSets {
    commonMain.dependencies {
        implementation(compose.runtime)
        implementation(compose.foundation)
        implementation(compose.material3)
        implementation(compose.ui)
        implementation(compose.components.resources)
        implementation(libs.koin.core)
        implementation(libs.koin.compose)
        implementation(libs.kotlinx.coroutines.core)
        implementation(libs.kotlinx.datetime)
        implementation(libs.sqldelight.runtime)
        implementation(libs.sqldelight.coroutines)
        implementation(libs.androidx.lifecycle.viewmodel)
        // Sprint 1 追加
        implementation(libs.coil.compose)
        implementation(libs.coil.core)
    }
    commonTest.dependencies {
        implementation(kotlin("test"))
        implementation(libs.kotlinx.coroutines.test)
    }
    androidMain.dependencies {
        implementation(libs.androidx.activity.compose)
        implementation(libs.koin.android)
        implementation(libs.sqldelight.android.driver)
        // Sprint 1 追加
        implementation(libs.androidx.camera.camera2)
        implementation(libs.androidx.camera.lifecycle)
        implementation(libs.androidx.camera.view)
    }
    iosMain.dependencies {
        implementation(libs.sqldelight.native.driver)
    }
}
```

- [ ] **Step 3: ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 4: コミット**

```bash
git add gradle/libs.versions.toml composeApp/build.gradle.kts
git commit -m "build: add CameraX, Coil3, coroutines-test dependencies for Sprint 1"
```

---

## Task 2: RecordPhotoUseCase（TDD）

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/RecordPhotoUseCase.kt`
- Create: `composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/RecordPhotoUseCaseTest.kt`
- Create: `composeApp/src/commonTest/kotlin/io/awairo/FakePhotoRepository.kt`

- [ ] **Step 1: FakePhotoRepository を作成**

```kotlin
// composeApp/src/commonTest/kotlin/io/awairo/FakePhotoRepository.kt
package io.awairo

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.toLocalDateTime

class FakePhotoRepository : PhotoRepository {
    val savedPhotos = mutableListOf<Photo>()

    override suspend fun save(photo: Photo) {
        savedPhotos.add(photo)
    }

    override suspend fun findById(id: String): Photo? =
        savedPhotos.find { it.id == id }

    override suspend fun findByLocalDate(date: LocalDate): List<Photo> {
        val tz = TimeZone.currentSystemDefault()
        val startOfDay = date.atStartOfDayIn(tz)
        val endOfDay = date.atStartOfDayIn(tz).plus(kotlinx.datetime.DateTimePeriod(days = 1), tz)
        return savedPhotos.filter {
            it.capturedAt >= startOfDay && it.capturedAt < endOfDay
        }
    }

    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> =
        savedPhotos.filter { it.developedAt <= now }

    override suspend fun delete(id: String) {
        savedPhotos.removeAll { it.id == id }
    }

    /** テスト用: 今日の日付の写真を1枚追加する */
    fun addPhotoForToday() {
        val now = kotlinx.datetime.Clock.System.now()
        savedPhotos.add(
            Photo(
                id = "test-id",
                capturedAt = now,
                developedAt = now.plus(kotlinx.datetime.DateTimePeriod(hours = 24), TimeZone.currentSystemDefault()),
                imagePath = "photos/test.jpg",
                memo = "",
                areaLabel = ""
            )
        )
    }
}
```

- [ ] **Step 2: 失敗するテストを先に書く**

```kotlin
// composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/RecordPhotoUseCaseTest.kt
package io.awairo.domain.usecase

import io.awairo.FakePhotoRepository
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RecordPhotoUseCaseTest {

    private val repo = FakePhotoRepository()
    private val useCase = RecordPhotoUseCase(repo)

    @Test
    fun `今日の写真がないとき、Successを返してDBに保存する`() = runTest {
        val result = useCase.execute(
            absoluteImagePath = "/data/photos/abc.jpg",
            memo = "テストメモ"
        )
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        assertEquals(1, repo.savedPhotos.size)
        assertEquals("photos/abc.jpg", repo.savedPhotos[0].imagePath)
        assertEquals("テストメモ", repo.savedPhotos[0].memo)
    }

    @Test
    fun `今日すでに写真があるとき、AlreadyTakenTodayを返す`() = runTest {
        repo.addPhotoForToday()
        val result = useCase.execute(
            absoluteImagePath = "/data/photos/xyz.jpg",
            memo = ""
        )
        assertEquals(RecordPhotoUseCase.Result.AlreadyTakenToday, result)
        assertEquals(1, repo.savedPhotos.size) // 新しく追加されていない
    }

    @Test
    fun `developedAtはcapturedAtの24時間後になる`() = runTest {
        val result = useCase.execute("/data/photos/abc.jpg", "")
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        val photo = result.photo
        val diffMillis = photo.developedAt.toEpochMilliseconds() - photo.capturedAt.toEpochMilliseconds()
        assertEquals(24 * 60 * 60 * 1000L, diffMillis)
    }

    @Test
    fun `メモが空文字でも保存できる`() = runTest {
        val result = useCase.execute("/data/photos/abc.jpg", "")
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        assertEquals("", result.photo.memo)
    }
}
```

- [ ] **Step 3: テストが失敗することを確認（クラス未定義エラーが出ればOK）**

```bash
./gradlew :composeApp:testDebugUnitTest 2>&1 | grep -E "error:|FAILED|Unresolved" | head -10
# Expected: "error: unresolved reference: RecordPhotoUseCase"
```

- [ ] **Step 4: RecordPhotoUseCase を実装**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/RecordPhotoUseCase.kt
package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.datetime.plus

class RecordPhotoUseCase(private val repository: PhotoRepository) {

    sealed class Result {
        data class Success(val photo: Photo) : Result()
        object AlreadyTakenToday : Result()
        data class Error(val cause: Throwable) : Result()
    }

    /**
     * 写真を記録する。
     * @param absoluteImagePath プラットフォームが返した画像の絶対パス（例: "/data/.../photos/abc.jpg"）
     * @param memo ユーザー入力のメモ（空文字可）
     */
    suspend fun execute(absoluteImagePath: String, memo: String): Result {
        return try {
            val now = Clock.System.now()
            val tz = TimeZone.currentSystemDefault()
            val today = now.toLocalDateTime(tz).date

            // 今日の写真が存在するかチェック
            val todayPhotos = repository.findByLocalDate(today)
            if (todayPhotos.isNotEmpty()) {
                return Result.AlreadyTakenToday
            }

            // 絶対パス → 相対パス変換: "/path/to/photos/abc.jpg" → "photos/abc.jpg"
            val filename = absoluteImagePath.substringAfterLast("/")
            val relativePath = "photos/$filename"

            val photo = Photo(
                id = generateId(),
                capturedAt = now,
                developedAt = now.plus(DateTimePeriod(hours = 24), tz),
                imagePath = relativePath,
                memo = memo,
                areaLabel = ""
            )
            repository.save(photo)
            Result.Success(photo)
        } catch (e: Throwable) {
            Result.Error(e)
        }
    }

    private fun generateId(): String {
        // KMP compatible UUID generation
        val chars = ('a'..'f') + ('0'..'9')
        fun seg(n: Int) = (1..n).map { chars.random() }.joinToString("")
        return "${seg(8)}-${seg(4)}-${seg(4)}-${seg(4)}-${seg(12)}"
    }
}
```

- [ ] **Step 5: テストが通ることを確認**

```bash
./gradlew :composeApp:testDebugUnitTest --tests "io.awairo.domain.usecase.RecordPhotoUseCaseTest"
# Expected: 4 tests passed
```

- [ ] **Step 6: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/RecordPhotoUseCase.kt \
        composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/RecordPhotoUseCaseTest.kt \
        composeApp/src/commonTest/kotlin/io/awairo/FakePhotoRepository.kt
git commit -m "feat: add RecordPhotoUseCase with 1-day-1-photo constraint"
```

---

## Task 3: HomeViewModel

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/HomeViewModel.kt`

- [ ] **Step 1: HomeViewModel を作成**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/HomeViewModel.kt
package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.repository.PhotoRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime

class HomeViewModel(private val repository: PhotoRepository) : ViewModel() {

    private val _isTodayPhotoTaken = MutableStateFlow(false)
    val isTodayPhotoTaken: StateFlow<Boolean> = _isTodayPhotoTaken

    init {
        refreshTodayStatus()
    }

    fun refreshTodayStatus() {
        viewModelScope.launch {
            val today = Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()).date
            val photos = repository.findByLocalDate(today)
            _isTodayPhotoTaken.value = photos.isNotEmpty()
        }
    }
}
```

- [ ] **Step 2: ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/HomeViewModel.kt
git commit -m "feat: add HomeViewModel for today photo status"
```

---

## Task 4: MemoViewModel

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/MemoViewModel.kt`

- [ ] **Step 1: MemoViewModel を作成**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/MemoViewModel.kt
package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.usecase.RecordPhotoUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class MemoViewModel(private val recordPhotoUseCase: RecordPhotoUseCase) : ViewModel() {

    sealed class SaveState {
        object Idle : SaveState()
        object Saving : SaveState()
        object Success : SaveState()
        data class Error(val message: String) : SaveState()
    }

    private val _saveState = MutableStateFlow<SaveState>(SaveState.Idle)
    val saveState: StateFlow<SaveState> = _saveState

    fun save(absoluteImagePath: String, memo: String) {
        viewModelScope.launch {
            _saveState.value = SaveState.Saving
            val result = recordPhotoUseCase.execute(absoluteImagePath, memo)
            _saveState.value = when (result) {
                is RecordPhotoUseCase.Result.Success -> SaveState.Success
                is RecordPhotoUseCase.Result.AlreadyTakenToday ->
                    SaveState.Error("今日はすでに1枚撮影済みです")
                is RecordPhotoUseCase.Result.Error ->
                    SaveState.Error("保存に失敗しました: ${result.cause.message}")
            }
        }
    }

    fun resetState() {
        _saveState.value = SaveState.Idle
    }
}
```

- [ ] **Step 2: ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/MemoViewModel.kt
git commit -m "feat: add MemoViewModel for photo save flow"
```

---

## Task 5: App.kt ナビゲーション

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/App.kt`

- [ ] **Step 1: App.kt を Screen state machine に更新**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/App.kt
package io.awairo

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import io.awairo.presentation.screen.HomeScreen
import io.awairo.presentation.screen.MemoScreen

sealed class Screen {
    object Home : Screen()
    data class Memo(val absoluteImagePath: String) : Screen()
}

@Composable
fun App() {
    var currentScreen: Screen by remember { mutableStateOf(Screen.Home) }

    MaterialTheme {
        Surface {
            when (val screen = currentScreen) {
                is Screen.Home -> HomeScreen(
                    onPhotoCaptured = { absolutePath ->
                        currentScreen = Screen.Memo(absolutePath)
                    }
                )
                is Screen.Memo -> MemoScreen(
                    absoluteImagePath = screen.absoluteImagePath,
                    onSaved = { currentScreen = Screen.Home },
                    onCancel = { currentScreen = Screen.Home }
                )
            }
        }
    }
}
```

- [ ] **Step 2: ビルドが通ることを確認（MemoScreen がまだないのでエラーが出る）**

```bash
./gradlew :composeApp:assembleDebug 2>&1 | grep "error:" | head -5
# Expected: "error: unresolved reference: MemoScreen" ← Task 6 で解消
```

- [ ] **Step 3: コミット（エラーがあってもコミットしてOK — 次のタスクで解消）**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/App.kt
git commit -m "feat: add Screen navigation state machine to App.kt"
```

---

## Task 6: MemoScreen + ファイル削除ユーティリティ

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/platform/FileUtils.kt`
- Create: `composeApp/src/androidMain/kotlin/io/awairo/platform/FileUtils.android.kt`
- Create: `composeApp/src/iosMain/kotlin/io/awairo/platform/FileUtils.ios.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/MemoScreen.kt`

- [ ] **Step 0a: deletePhotoFile expect を作成（キャンセル・保存失敗時のクリーンアップ用）**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/platform/FileUtils.kt
package io.awairo.platform

/**
 * 撮影した画像ファイルを削除する。
 * キャンセル時・DB保存失敗時のクリーンアップに使う。
 */
expect fun deletePhotoFile(absolutePath: String)
```

- [ ] **Step 0b: Android actual を作成**

```kotlin
// composeApp/src/androidMain/kotlin/io/awairo/platform/FileUtils.android.kt
package io.awairo.platform

import java.io.File

actual fun deletePhotoFile(absolutePath: String) {
    File(absolutePath).delete()
}
```

- [ ] **Step 0c: iOS actual を作成**

```kotlin
// composeApp/src/iosMain/kotlin/io/awairo/platform/FileUtils.ios.kt
package io.awairo.platform

import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSFileManager

@OptIn(ExperimentalForeignApi::class)
actual fun deletePhotoFile(absolutePath: String) {
    NSFileManager.defaultManager.removeItemAtPath(absolutePath, error = null)
}
```

- [ ] **Step 1: MemoScreen を作成**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/MemoScreen.kt
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
```

- [ ] **Step 2: ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/platform/FileUtils.kt \
        composeApp/src/androidMain/kotlin/io/awairo/platform/FileUtils.android.kt \
        composeApp/src/iosMain/kotlin/io/awairo/platform/FileUtils.ios.kt \
        composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/MemoScreen.kt
git commit -m "feat: add MemoScreen with photo thumbnail, memo input, and file cleanup on cancel/error"
```

---

## Task 7: BubbleCameraView + bubbleDistortion（commonMain）

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleCameraView.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/platform/camera/BubbleDistortion.kt`

> このタスクでは CameraController は expect のみ（actual 未実装）。  
> BubbleCameraView はコンパイルできるが、実際にカメラは映らない段階。

- [ ] **Step 1: bubbleDistortion Modifier を作成（pure Compose、expect/actual なし）**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/platform/camera/BubbleDistortion.kt
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
```

- [ ] **Step 2: CameraController expect class のスタブを作成（actual は Task 8 以降）**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/platform/camera/CameraController.kt
package io.awairo.platform.camera

/**
 * プラットフォーム固有のカメラ制御クラス。
 * Android: CameraX / iOS: AVFoundation
 */
expect class CameraController {
    /** カメラパーミッションが許可されているか */
    fun hasPermission(): Boolean
    /**
     * 現在のフレームを撮影してファイルに保存する。
     * @return 画像の絶対パス（例: "/data/.../photos/abc.jpg"）、失敗時は null
     */
    suspend fun capture(): String?
    /** カメラリソースを解放する（ライフサイクル終了時に呼ぶ） */
    fun release()
}
```

- [ ] **Step 3: CameraPreview expect composable のスタブを作成**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/platform/camera/CameraPreview.kt
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
```

- [ ] **Step 4: BubbleCameraView を作成**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleCameraView.kt
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
```

- [ ] **Step 5: ビルドは失敗する（actual 未実装）— エラー内容を確認するだけでOK**

```bash
./gradlew :composeApp:assembleDebug 2>&1 | grep "error:" | head -10
# Expected: "Expected class 'CameraController' has no actual declaration"
# → Task 8 以降で actual を追加して解消する
```

- [ ] **Step 6: コミット（actual がなくてもコミットする）**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/platform/camera/ \
        composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleCameraView.kt
git commit -m "feat: add BubbleCameraView, bubbleDistortion, CameraController/CameraPreview expect declarations"
```

---

## Task 8: CameraController Android actual（CameraX）

**Files:**
- Create: `composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraController.android.kt`

- [ ] **Step 1: Android actual を作成**

```kotlin
// composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraController.android.kt
package io.awairo.platform.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.core.content.ContextCompat
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume

actual class CameraController(private val context: Context) {

    // CameraPreview.android.kt から参照される
    internal val imageCapture: ImageCapture = ImageCapture.Builder().build()

    private val photosDir: File by lazy {
        File(context.filesDir, "photos").also { it.mkdirs() }
    }

    actual fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

    actual suspend fun capture(): String? = suspendCancellableCoroutine { cont ->
        val file = File(photosDir, "${UUID.randomUUID()}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(file).build()

        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    cont.resume(file.absolutePath)
                }
                override fun onError(exception: ImageCaptureException) {
                    cont.resume(null)
                }
            }
        )
    }

    actual fun release() {
        // CameraX のバインドは CameraPreview コンポーザブル内で管理するため、ここでは何もしない
    }
}
```

- [ ] **Step 2: コミット**

```bash
git add composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraController.android.kt
git commit -m "feat: add CameraController Android actual with CameraX"
```

---

## Task 9: CameraPreview Android actual

**Files:**
- Create: `composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraPreview.android.kt`

- [ ] **Step 1: Android actual composable を作成**

```kotlin
// composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraPreview.android.kt
package io.awairo.platform.camera

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner

@Composable
actual fun CameraPreview(
    controller: CameraController,
    modifier: Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var hasPermission by remember { mutableStateOf(controller.hasPermission()) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasPermission = granted
    }

    // 初回: パーミッションがなければリクエスト
    LaunchedEffect(Unit) {
        if (!hasPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    if (hasPermission) {
        AndroidView(
            factory = { ctx ->
                PreviewView(ctx).apply {
                    implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                    val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                    cameraProviderFuture.addListener({
                        val cameraProvider = cameraProviderFuture.get()
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(surfaceProvider)
                        }
                        try {
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                CameraSelector.DEFAULT_BACK_CAMERA,
                                preview,
                                controller.imageCapture  // CameraController と共有
                            )
                        } catch (e: Exception) {
                            // カメラバインドエラー（シミュレーターでは発生しうる）
                        }
                    }, ContextCompat.getMainExecutor(ctx))
                }
            },
            modifier = modifier
        )
    }
    // パーミッションなし → 何も表示しない（BubbleCameraView がパーミッション状態を管理）
}
```

- [ ] **Step 2: Android ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL (iOS actual がまだないので ios ビルドは後回し)
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/androidMain/kotlin/io/awairo/platform/camera/CameraPreview.android.kt
git commit -m "feat: add CameraPreview Android actual with CameraX and permission handling"
```

---

## Task 10: CameraController iOS actual（AVFoundation）

**Files:**
- Create: `composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraController.ios.kt`

> **注意**: Kotlin/Native から AVFoundation の Objective-C API を呼ぶ。  
> `import platform.AVFoundation.*` でインポート可能。

- [ ] **Step 1: iOS actual を作成**

```kotlin
// composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraController.ios.kt
package io.awairo.platform.camera

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.suspendCancellableCoroutine
import platform.AVFoundation.AVAuthorizationStatusAuthorized
import platform.AVFoundation.AVCaptureDevice
import platform.AVFoundation.AVCaptureDeviceInput
import platform.AVFoundation.AVCapturePhoto
import platform.AVFoundation.AVCapturePhotoCaptureDelegate
import platform.AVFoundation.AVCapturePhotoOutput
import platform.AVFoundation.AVCapturePhotoSettings
import platform.AVFoundation.AVCaptureSession
import platform.AVFoundation.AVCaptureSessionPresetPhoto
import platform.AVFoundation.AVCaptureVideoPreviewLayer
import platform.AVFoundation.AVMediaTypeVideo
import platform.Foundation.NSApplicationSupportDirectory
import platform.Foundation.NSData
import platform.Foundation.NSError
import platform.Foundation.NSFileManager
import platform.Foundation.NSSearchPathForDirectoriesInDomains
import platform.Foundation.NSUserDomainMask
import platform.Foundation.NSURL
import platform.Foundation.NSUUID
import platform.Foundation.writeToFile
import platform.UIKit.UIView
import kotlin.coroutines.resume

@OptIn(ExperimentalForeignApi::class)
actual class CameraController {

    // CameraPreview.ios.kt から参照される
    internal val session: AVCaptureSession = AVCaptureSession()
    private val photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    private val photosDir: String by lazy { setupPhotosDir() }

    init {
        setupSession()
    }

    private fun setupSession() {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto

        val device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if (device != null) {
            val input = AVCaptureDeviceInput.deviceInputWithDevice(device, null)
            if (input != null && session.canAddInput(input)) {
                session.addInput(input)
            }
        }
        if (session.canAddOutput(photoOutput)) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    private fun setupPhotosDir(): String {
        val paths = NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory,
            NSUserDomainMask,
            true
        )
        val appSupport = paths.firstOrNull() as? String ?: ""
        val dir = "$appSupport/photos"
        NSFileManager.defaultManager.createDirectoryAtPath(
            dir,
            withIntermediateDirectories = true,
            attributes = null,
            error = null
        )
        return dir
    }

    actual fun hasPermission(): Boolean =
        AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) ==
                AVAuthorizationStatusAuthorized

    actual suspend fun capture(): String? = suspendCancellableCoroutine { cont ->
        val settings = AVCapturePhotoSettings()
        val filename = "${NSUUID().UUIDString}.jpg"
        val filePath = "$photosDir/$filename"

        photoOutput.capturePhotoWithSettings(
            settings,
            delegate = object : AVCapturePhotoCaptureDelegate {
                override fun captureOutput(
                    output: AVCapturePhotoOutput,
                    didFinishProcessingPhoto: AVCapturePhoto,
                    error: NSError?
                ) {
                    if (error != null) {
                        cont.resume(null)
                        return
                    }
                    val data = didFinishProcessingPhoto.fileDataRepresentation()
                    if (data == null) {
                        cont.resume(null)
                        return
                    }
                    val saved = data.writeToFile(filePath, atomically = true)
                    cont.resume(if (saved) filePath else null)
                }
            }
        )
    }

    actual fun release() {
        if (session.running) {
            session.stopRunning()
        }
    }
}
```

- [ ] **Step 2: コミット**

```bash
git add composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraController.ios.kt
git commit -m "feat: add CameraController iOS actual with AVFoundation"
```

---

## Task 11: CameraPreview iOS actual

**Files:**
- Create: `composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraPreview.ios.kt`

- [ ] **Step 1: iOS actual composable を作成**

```kotlin
// composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraPreview.ios.kt
package io.awairo.platform.camera

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.UIKitView
import kotlinx.cinterop.ExperimentalForeignApi
import platform.AVFoundation.AVCaptureDevice
import platform.AVFoundation.AVCaptureVideoPreviewLayer
import platform.AVFoundation.AVLayerVideoGravityResizeAspectFill
import platform.AVFoundation.AVMediaTypeVideo
import platform.AVFoundation.requestAccessForMediaType
import platform.QuartzCore.CATransaction
import platform.QuartzCore.kCATransactionDisableActions
import platform.UIKit.UIView

@OptIn(ExperimentalForeignApi::class)
@Composable
actual fun CameraPreview(
    controller: CameraController,
    modifier: Modifier
) {
    // iOS は初回アクセス時に自動でパーミッションダイアログを表示する
    LaunchedEffect(Unit) {
        if (!controller.hasPermission()) {
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { _ -> }
        }
    }

    DisposableEffect(Unit) {
        controller.session.startRunning()
        onDispose {
            controller.session.stopRunning()
        }
    }

    UIKitView(
        factory = {
            val view = UIView()
            val previewLayer = AVCaptureVideoPreviewLayer(session = controller.session)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            CATransaction.begin()
            CATransaction.setValue(true, forKey = kCATransactionDisableActions)
            view.layer.addSublayer(previewLayer)
            CATransaction.commit()
            // previewLayer のサイズは update で調整する
            view
        },
        update = { view ->
            // UIKitView がリサイズされるたびに previewLayer のフレームを更新
            val previewLayer = view.layer.sublayers
                ?.filterIsInstance<AVCaptureVideoPreviewLayer>()
                ?.firstOrNull()
            CATransaction.begin()
            CATransaction.setValue(true, forKey = kCATransactionDisableActions)
            previewLayer?.frame = view.bounds
            CATransaction.commit()
        },
        modifier = modifier
    )
}
```

- [ ] **Step 2: iOS フレームワークのビルドが通ることを確認**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/iosMain/kotlin/io/awairo/platform/camera/CameraPreview.ios.kt
git commit -m "feat: add CameraPreview iOS actual with AVCaptureVideoPreviewLayer"
```

---

## Task 12: HomeScreen 更新

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt`

- [ ] **Step 1: HomeScreen を泡UIに更新**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt
package io.awairo.presentation.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.awairo.platform.camera.CameraController
import io.awairo.presentation.component.BubbleCameraView
import io.awairo.presentation.component.GrayedOutBubble
import io.awairo.presentation.viewmodel.HomeViewModel
import org.koin.compose.koinInject
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun HomeScreen(
    onPhotoCaptured: (absoluteImagePath: String) -> Unit,
    viewModel: HomeViewModel = koinViewModel()
) {
    val isTodayPhotoTaken by viewModel.isTodayPhotoTaken.collectAsState()
    val cameraController = koinInject<CameraController>()

    // 画面に戻ってきたときに状態を再チェック
    LaunchedEffect(Unit) {
        viewModel.refreshTodayStatus()
    }

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        if (isTodayPhotoTaken) {
            // 撮影済み → グレーアウトした泡
            GrayedOutBubble()
        } else {
            // 未撮影 → カメラプレビューの泡
            if (cameraController.hasPermission()) {
                BubbleCameraView(
                    controller = cameraController,
                    onCaptured = { path ->
                        viewModel.refreshTodayStatus()
                        onPhotoCaptured(path)
                    }
                )
            } else {
                // パーミッション未許可状態の表示
                CameraPermissionUI(cameraController = cameraController)
            }
        }
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
```

- [ ] **Step 2: Android ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 3: iOS ビルドが通ることを確認**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt
git commit -m "feat: update HomeScreen with BubbleCameraView and grayed-out state"
```

---

## Task 13: DI + パーミッション設定

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt`
- Modify: `composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt`
- Modify: `composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt`
- Modify: `composeApp/src/androidMain/AndroidManifest.xml`
- Modify: `iosApp/iosApp.xcodeproj/project.pbxproj`（Xcode設定）

- [ ] **Step 1: AppModule に ViewModel と UseCase を追加**

```kotlin
// composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.usecase.RecordPhotoUseCase
import io.awairo.presentation.viewmodel.HomeViewModel
import io.awairo.presentation.viewmodel.MemoViewModel
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

fun appModule() = module {
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }
    // Sprint 1 追加
    factory { RecordPhotoUseCase(get()) }
    viewModel { HomeViewModel(get()) }
    viewModel { MemoViewModel(get()) }
}
```

- [ ] **Step 2: AndroidModule に CameraController を追加**

```kotlin
// composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

fun androidModule() = module {
    single { DatabaseFactory(androidContext()) }
    // Sprint 1 追加
    single { CameraController(androidContext()) }
}
```

- [ ] **Step 3: IosModule に CameraController を追加**

```kotlin
// composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.core.context.startKoin
import org.koin.dsl.module

fun iosModule() = module {
    single { DatabaseFactory() }
    // Sprint 1 追加
    single { CameraController() }
}

fun initKoinForIos() {
    startKoin {
        modules(iosModule(), appModule())
    }
}
```

- [ ] **Step 4: AndroidManifest に CAMERA パーミッションを追加**

```xml
<!-- composeApp/src/androidMain/AndroidManifest.xml -->
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Sprint 1 追加 -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />

    <application
        android:name=".AwaIroApplication"
        android:allowBackup="false"
        android:label="AwaIro"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|screenLayout|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
```

- [ ] **Step 5: iOS カメラパーミッション説明文を Xcode プロジェクトに追加**

`iosApp/iosApp.xcodeproj/project.pbxproj` の `A100000100000000000000F0` (Debug) と `A100000100000000000000F1` (Release) の `buildSettings` に以下を追加:

```
INFOPLIST_KEY_NSCameraUsageDescription = "泡を通して今日の1枚を撮影します";
```

具体的には、両ターゲット設定の `GENERATE_INFOPLIST_FILE = YES;` の直後に以下を追加:

```
INFOPLIST_KEY_NSCameraUsageDescription = "泡を通して今日の1枚を撮影します";
```

- [ ] **Step 6: Android フルビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 7: iOS フレームワークビルドが通ることを確認**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
# Expected: BUILD SUCCESSFUL
```

- [ ] **Step 8: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt \
        composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt \
        composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt \
        composeApp/src/androidMain/AndroidManifest.xml \
        iosApp/iosApp.xcodeproj/project.pbxproj
git commit -m "feat: wire up DI, camera permissions for Android and iOS"
```

---

## Task 14: CI 更新 + 動作確認

**Files:**
- Modify: `.github/workflows/ci.yml`（iOS ビルドコマンドを確認）

- [ ] **Step 1: CI が通ることを確認（push で自動実行）**

```bash
git push origin main
# GitHub Actions で build-android と build-ios が GREEN になることを確認
# → https://github.com/nus-nody/AwaIro/actions
```

- [ ] **Step 2: Android エミュレーターで動作確認**

```bash
# エミュレーターが起動していることを確認
$ANDROID_HOME/emulator/emulator -list-avds
# → Pixel_7_API35_AwaIro が表示されること

# インストール & 起動
./gradlew :composeApp:installDebug
adb shell am start -n io.awairo/.MainActivity

# Android エミュレーターではカメラが「シミュレート」される
# → 泡が表示されるか確認（実際の映像は出ないが、UIが崩れないこと）
```

- [ ] **Step 3: iOS シミュレーターで動作確認**

```bash
# iPhone 16 (AwaIro) シミュレーターでビルド & 起動
xcrun simctl boot E9A6A300-00B7-4538-87A9-C322671FC5F9 2>/dev/null || true

xcodebuild \
  -project iosApp/iosApp.xcodeproj \
  -scheme iosApp \
  -sdk iphonesimulator \
  -destination "id=E9A6A300-00B7-4538-87A9-C322671FC5F9" \
  -configuration Debug \
  OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
# Expected: BUILD SUCCEEDED

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "iosApp.app" \
  -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
xcrun simctl install E9A6A300-00B7-4538-87A9-C322671FC5F9 "$APP_PATH"
xcrun simctl launch E9A6A300-00B7-4538-87A9-C322671FC5F9 io.awairo
sleep 5
xcrun simctl io E9A6A300-00B7-4538-87A9-C322671FC5F9 screenshot /tmp/sprint1-ios.png
# → スクリーンショットを確認: 泡 or カメラパーミッション画面が表示されること
```

- [ ] **Step 4: 完了条件チェックリストを確認**

```
[ ] 泡にカメラプレビューが映る（Android / iOS 両方）
[ ] 泡に歪みエフェクトがかかっている
[ ] タップで撮影 → MemoScreen に遷移する
[ ] メモ入力なしで保存できる
[ ] メモ入力ありで保存できる
[ ] 保存後 HomeScreen に戻り、泡がグレーアウトする
[ ] アプリ再起動後も当日撮影済みなら泡はグレーアウトのまま
[ ] 日付が変わると（端末の日付を設定アプリで進めて確認）泡が再びアクティブになる
[ ] カメラパーミッション拒否時にエラー表示が出る
[ ] MemoScreen でキャンセル時に画像ファイルが削除されている（adb shell / Files.app で確認）
```

- [ ] **Step 5: Sprint 1 完了タグを打つ**

```bash
git tag v0.2.0-sprint1
git push origin v0.2.0-sprint1
```

---

## 実装上の注意点

### iOS シミュレーターとカメラ
iOS シミュレーターは実際のカメラを持たない。`AVCaptureSession.startRunning()` はエラーにならないが、プレビューは表示されない（黒い泡になる）。実機で確認するか、シミュレーターではカメラ部分はスキップしてUIの動作確認に集中する。

### Android エミュレーターとカメラ
Android エミュレーター（API 34+）は仮想カメラをサポートする。「Extended Controls → Camera」で画像を設定すると、カメラプレビューに映像が映る。

### ForeignApi アノテーション
iOS actual での `@OptIn(ExperimentalForeignApi::class)` は Kotlin/Native の Objective-C interop で必要。コンパイルエラーが出た場合はすべての iOS actual ファイルに `@file:OptIn(ExperimentalForeignApi::class)` をファイル先頭に追加する。

### viewModelDsl DSL
`org.koin.core.module.dsl.viewModel` を使う場合、Koin 4.x では `org.koin.compose.viewmodel.koinViewModel()` を Composable で使う。インポートが `org.koin.compose.viewmodel.koinViewModel` であることに注意（`org.koin.androidx.compose.koinViewModel` ではない）。

---

*AwaIro — Sprint 1 実装計画: 2026-04-25*
