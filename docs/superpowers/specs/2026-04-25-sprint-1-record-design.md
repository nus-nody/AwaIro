# Sprint 1 設計書 — Record（記録する）

**作成日**: 2026-04-25  
**対象Sprint**: Sprint 1  
**前提**: Sprint 0 完了済み（KMP基盤・SQLDelight・Koin・CI/CD 動作確認済み）  
**実装開始**: 新セッションで開始（本ドキュメントが唯一の引き継ぎ資料）

---

## 1. Sprint 1 のゴール

ユーザーが「泡」をタップすることで、その瞬間の映像を1枚撮影・保存できる。  
カメラアプリを意識させない。泡の向こう側の世界が歪んで見えていて、タップした瞬間にそれが切り取られる体験。

**完了条件：**
```
[ ] 泡にカメラプレビューが映る（Android / iOS 両方）
[ ] 泡に歪みエフェクトがかかっている
[ ] タップで撮影 → MemoScreen に遷移する
[ ] メモ入力なしで保存できる
[ ] メモ入力ありで保存できる
[ ] 保存後 HomeScreen に戻り、泡がグレーアウトする
[ ] アプリ再起動後も当日撮影済みなら泡はグレーアウトのまま
[ ] 日付が変わると（端末の日付を進めて確認）泡が再びアクティブになる
[ ] カメラパーミッション拒否時にエラー表示が出る
```

---

## 2. ユーザー体験フロー

```
起動
  └─ HomeScreen
       ├─ 今日未撮影
       │    └─ 泡（カメラプレビュー + 球面歪みエフェクト）が表示
       │         └─ タップ
       │              └─ その瞬間を撮影（ファイル保存）
       │                   └─ MemoScreen
       │                        ├─ メモ入力（任意）
       │                        └─ 「残す」ボタン
       │                             └─ DBに保存 → HomeScreen（泡グレーアウト）
       └─ 今日撮影済み
            └─ 泡がグレーアウト（タップ不可）
```

**重要な体験設計の意図：**
- ユーザーはカメラを「起動」しない。常に泡の向こうが見えていて、タップで「切り取る」
- メモは任意。空欄で保存可能
- 保存後の確認画面はなし。潔く HomeScreen に戻る

---

## 3. アーキテクチャ

### 3-1. ディレクトリ構成（追加・変更分のみ）

```
composeApp/src/
├─ commonMain/kotlin/io/awairo/
│   ├─ App.kt                          ← Screen状態管理を追加
│   ├─ domain/usecase/
│   │   └─ RecordPhotoUseCase.kt       ← 新規：1日1枚制限 + 保存
│   ├─ platform/camera/
│   │   ├─ CameraController.kt         ← 新規：expect class
│   │   └─ BubbleDistortion.kt         ← 新規：expect fun Modifier.bubbleDistortion()
│   └─ presentation/
│       ├─ screen/
│       │   ├─ HomeScreen.kt           ← 変更：泡UI追加
│       │   └─ MemoScreen.kt           ← 新規：メモ入力画面
│       ├─ viewmodel/
│       │   ├─ HomeViewModel.kt        ← 新規：今日の撮影状態管理
│       │   └─ MemoViewModel.kt        ← 新規：保存処理
│       └─ component/
│           └─ BubbleCameraView.kt     ← 新規：泡コンポーネント
│
├─ androidMain/kotlin/io/awairo/
│   └─ platform/camera/
│       ├─ CameraController.android.kt ← 新規：CameraX 実装
│       └─ BubbleDistortion.android.kt ← 新規：AGSL シェーダー実装
│
└─ iosMain/kotlin/io/awairo/
    └─ platform/camera/
        ├─ CameraController.ios.kt     ← 新規：AVFoundation 実装
        └─ BubbleDistortion.ios.kt     ← 新規：Core Image フィルター実装
```

### 3-2. ナビゲーション

外部ライブラリなし。`App.kt` でシンプルな sealed class による状態管理。

```kotlin
// App.kt
sealed class Screen {
    object Home : Screen()
    data class Memo(val imagePath: String) : Screen()
}

@Composable
fun App() {
    var currentScreen: Screen by remember { mutableStateOf(Screen.Home) }
    MaterialTheme {
        Surface {
            when (val screen = currentScreen) {
                is Screen.Home -> HomeScreen(
                    onPhotoCaptured = { path -> currentScreen = Screen.Memo(path) }
                )
                is Screen.Memo -> MemoScreen(
                    imagePath = screen.imagePath,
                    onSaved = { currentScreen = Screen.Home },
                    onCancel = { currentScreen = Screen.Home }
                )
            }
        }
    }
}
```

---

## 4. 各コンポーネント設計

### 4-1. `expect class CameraController`

```kotlin
// commonMain/platform/camera/CameraController.kt
expect class CameraController {
    /** カメラプレビューを開始する */
    fun startPreview()
    /** カメラプレビューを停止する（onStop 時に呼ぶ） */
    fun stopPreview()
    /**
     * 現在のフレームを撮影しファイルに保存する
     * @return 保存した画像の相対パス ("photos/xxxx.jpg")、失敗時は null
     */
    suspend fun capture(): String?
    /** パーミッション状態を返す */
    fun hasPermission(): Boolean
    /** パーミッションをリクエストする */
    suspend fun requestPermission(): Boolean
}
```

**Android 実装方針（CameraX）：**
- `ProcessCameraProvider` で `Preview` + `ImageCapture` をバインド
- プレビューは `PreviewView` を `AndroidView` として Composable に埋め込む
- `ImageCapture.takePicture()` で `context.filesDir/photos/` に保存

**iOS 実装方針（AVFoundation）：**
- `AVCaptureSession` + `AVCaptureVideoPreviewLayer`
- Compose Multiplatform の `UIKitView` でプレビューを Composable に埋め込む
- `AVCapturePhotoOutput.capturePhoto()` で Application Support/photos/ に保存

### 4-2. `expect fun Modifier.bubbleDistortion()`

```kotlin
// commonMain/platform/camera/BubbleDistortion.kt
expect fun Modifier.bubbleDistortion(): Modifier
```

**Android 実装（AGSL シェーダー / API 33+）：**
- `RenderEffect.createRuntimeShaderEffect()` でバレル歪みシェーダーを適用
- API 33未満フォールバック：円形クリップ + `graphicsLayer { scaleX = 1.1f; scaleY = 1.1f }`

**iOS 実装（Core Image）：**
- `CIFilter(name: "CIBumpDistortion")` を `UIImageView` に適用
- フォールバック：円形クリップ + スケールアップ

**共通の視覚仕上げ（BubbleCameraView.kt 内で Compose 描画）：**
- 円形クリップ（`clip(CircleShape)`）
- 外縁にガラス感のグラデーションオーバーレイ（`Canvas` で描画）
- 軽いシャドウ（`shadow(elevation = 8.dp, shape = CircleShape)`）

### 4-3. `BubbleCameraView.kt`

```kotlin
// commonMain/presentation/component/BubbleCameraView.kt
@Composable
fun BubbleCameraView(
    controller: CameraController,
    onCaptured: (imagePath: String) -> Unit,
    modifier: Modifier = Modifier
)
```

- `controller.startPreview()` を `LaunchedEffect` で呼び出し
- `DisposableEffect` で `controller.stopPreview()` を登録
- `Modifier.bubbleDistortion()` を適用
- タップ（`pointerInput`）で `controller.capture()` を呼び出し、成功時に `onCaptured` を呼ぶ

### 4-4. `HomeScreen.kt`（変更）

```kotlin
@Composable
fun HomeScreen(
    onPhotoCaptured: (imagePath: String) -> Unit,
    viewModel: HomeViewModel = koinViewModel()
)
```

- `viewModel.isTodayPhotoTaken: StateFlow<Boolean>` を監視
- `false` → `BubbleCameraView` を表示
- `true` → グレーアウトした泡（静止画、タップ不可）を表示
- カメラパーミッション未許可 → 「カメラへのアクセスが必要です」テキスト + 設定へのボタン

### 4-5. `HomeViewModel.kt`

```kotlin
class HomeViewModel(private val repository: PhotoRepository) : ViewModel() {
    val isTodayPhotoTaken: StateFlow<Boolean>

    init {
        // repository.findByLocalDate(today).isNotEmpty() で判定
        // ※ PhotoRepository に countByLocalDate を追加するか、
        //   findByLocalDate の結果で判定する（Sprint 1 は後者で十分）
    }
}
```

> **実装注意**: `PhotoRepository` インターフェースには現在 `findByLocalDate(date)` が定義済み。  
> SQLDelight の `countByDateRange` クエリは `LocalPhotoRepository` 内で直接呼ぶか、  
> インターフェースに `suspend fun countByLocalDate(date: LocalDate): Long` を追加して使う。

### 4-6. `RecordPhotoUseCase.kt`

```kotlin
// commonMain/domain/usecase/RecordPhotoUseCase.kt
class RecordPhotoUseCase(private val repository: PhotoRepository) {
    sealed class Result {
        data class Success(val photo: Photo) : Result()
        object AlreadyTakenToday : Result()
        data class Error(val cause: Throwable) : Result()
    }

    suspend fun execute(imagePath: String, memo: String): Result
}
```

- 今日の撮影枚数を `countByDateRange` で確認
- 0枚 → `Photo` 生成（`developedAt = capturedAt + 24h`）→ `repository.save()`
- 1枚以上 → `AlreadyTakenToday` 返却（通常は泡グレーで到達不可のフェイルセーフ）

### 4-7. `MemoScreen.kt`（新規）

```kotlin
@Composable
fun MemoScreen(
    imagePath: String,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    viewModel: MemoViewModel = koinViewModel()
)
```

- `imagePath` の画像をサムネイル表示
- メモのテキスト入力欄（任意・空欄可）
- 「残す」ボタン → `viewModel.save(imagePath, memo)`
- 戻るボタン（キャンセル）→ `onCancel()` + 画像ファイル削除
- 保存成功 → `onSaved()`
- 保存失敗 → Snackbar でエラー表示 + 画像ファイル削除

---

## 5. データフロー

```
画像ファイルの保存場所:
  Android: {context.filesDir}/photos/{uuid}.jpg
  iOS:     {ApplicationSupport}/photos/{uuid}.jpg
  DB保存値: "photos/{uuid}.jpg" （相対パス）

Photo ドメインモデル（変更なし）:
  id          = UUID.randomUUID().toString()
  capturedAt  = Clock.System.now()
  developedAt = capturedAt + 24.hours
  imagePath   = "photos/{uuid}.jpg"
  memo        = ユーザー入力（空文字可）
  areaLabel   = "" （Sprint 1では空、将来拡張）
```

---

## 6. エラーハンドリング

| ケース | 対応 |
|--------|------|
| カメラパーミッション未許可 | HomeScreen でエラーUI表示（泡の代わり）、設定アプリへの誘導ボタン |
| 撮影中にアプリがバックグラウンドへ | `onStop` で `CameraController.stopPreview()`、`onStart` で再バインド |
| 画像ファイル保存失敗 | MemoScreen に進まず HomeScreen で Snackbar エラー |
| DB保存失敗 | MemoScreen で Snackbar、画像ファイルを削除してクリーンアップ |
| メモ未入力で保存 | 正常（空文字で保存） |
| Android API 33未満での歪みエフェクト | 円形クリップ + ズームのフォールバック |

---

## 7. DI（Koin）追加設定

```kotlin
// AppModule.kt に追加
fun appModule() = module {
    // 既存
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }

    // Sprint 1 追加
    factory { RecordPhotoUseCase(get()) }
    viewModel { HomeViewModel(get()) }
    viewModel { MemoViewModel(get()) }
}

// platformModule（Android / iOS 別）に追加
// CameraController は platform 依存なので platformModule に定義
single { CameraController(/* platform context */) }
```

---

## 8. 依存ライブラリ追加

```toml
# gradle/libs.versions.toml に追加
camerax = "1.4.1"
androidx-camera-camera2 = { module = "androidx.camera:camera-camera2", version.ref = "camerax" }
androidx-camera-lifecycle = { module = "androidx.camera:camera-lifecycle", version.ref = "camerax" }
androidx-camera-view = { module = "androidx.camera:camera-view", version.ref = "camerax" }
```

```kotlin
# composeApp/build.gradle.kts の androidMain.dependencies に追加
implementation(libs.androidx.camera.camera2)
implementation(libs.androidx.camera.lifecycle)
implementation(libs.androidx.camera.view)
```

iOS側は AVFoundation / Core Image がシステムフレームワークのため追加不要。

---

## 9. 既存コードへの変更点

| ファイル | 変更内容 |
|--------|---------|
| `App.kt` | `Screen` sealed class 追加、`HomeScreen` / `MemoScreen` のルーティング追加 |
| `HomeScreen.kt` | ハードコードテキストを削除、`BubbleCameraView` / グレーアウト泡 / パーミッションエラーUIを追加 |
| `AppModule.kt` | `RecordPhotoUseCase`・`HomeViewModel`・`MemoViewModel` をDI登録 |
| `AndroidManifest.xml` | `<uses-permission android:name="android.permission.CAMERA" />` 追加 |
| `iosMain/Info.plist` | `NSCameraUsageDescription` 追加（Xcodeビルド設定 `INFOPLIST_KEY_NSCameraUsageDescription`） |

---

## 10. Sprint 1 実装順序（推奨）

1. **`RecordPhotoUseCase`** — ビジネスロジックから始める（テストしやすい）
2. **`HomeViewModel`** — 今日の撮影状態管理
3. **`MemoScreen` + `MemoViewModel`** — UIとロジックの骨格
4. **`App.kt` ナビゲーション** — Screen状態管理
5. **`CameraController` (Android)** — CameraX でプレビュー + 撮影
6. **`CameraController` (iOS)** — AVFoundation でプレビュー + 撮影
7. **`BubbleCameraView`** — カメラプレビューを泡に表示
8. **`BubbleDistortion` (Android)** — AGSL 歪みエフェクト
9. **`BubbleDistortion` (iOS)** — Core Image 歪みエフェクト
10. **`HomeScreen` 仕上げ** — グレーアウト・パーミッション状態の表示

---

## 11. 新セッション開始時の確認事項

```bash
# シミュレーター状態確認
xcrun simctl list devices | grep -E "AwaIro|Booted"

# Android エミュレーター確認
$ANDROID_HOME/emulator/emulator -list-avds

# ビルド確認（変更前のベースラインとして）
./gradlew :composeApp:assembleDebug
```

**実装開始前に読むべきファイル：**
- `docs/superpowers/specs/2026-04-24-awairo-design.md` — 全体設計
- `docs/superpowers/specs/2026-04-25-sprint-1-record-design.md` — 本ファイル
- `docs/retros/2026-04-25-sprint-0-retrospective.md` — Xcode設定の注意点

---

*AwaIro Project — Sprint 1 設計完了: 2026-04-25*
