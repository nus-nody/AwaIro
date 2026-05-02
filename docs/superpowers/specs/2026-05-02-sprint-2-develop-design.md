# Sprint 2 設計書 — Develop（現像する）

**作成日**: 2026-05-02
**対象 Sprint**: Sprint 2
**前提**: Sprint 1 完了済み（v0.2.0-sprint1 タグ済み・main にマージ済み）
**実装開始**: 翌日以降（本ドキュメントが唯一の引き継ぎ資料）

---

## 1. Sprint 2 のゴール

撮影から 24 時間経過した「現像済み」の泡だけがギャラリーで写真として見える。
未現像の泡は中身が透けて見えず、「あと○時間」だけが薄く浮かぶ。
泡たちは空にふわふわと舞い上がり、最新が上にいる。

タップすると泡が割れて写真が現れ、メモを読んだり編集したりできる。
左右スワイプで前後の泡を行き来できる。

**完了条件**:

- [ ] HomeScreen 左下にギャラリーボタン、右下にメニューボタンが配置される
- [ ] ギャラリーボタンで GalleryScreen に遷移する
- [ ] GalleryScreen で泡が縦スクロールで並び、ふわふわアニメーションする
- [ ] 最新の撮影が一番上に、古い撮影が下に並ぶ
- [ ] 現像済みの泡は写真が中に見える
- [ ] 未現像の泡は透明で「あと○時間」が表示される
- [ ] 24 時間経過後、再度ギャラリーを開くと未現像が現像済みに切り替わる
- [ ] 現像済みの泡をタップすると泡が割れて PhotoDetailScreen に遷移する
- [ ] PhotoDetailScreen で写真が拡大表示され、メモが読める
- [ ] PhotoDetailScreen でメモを編集できる
- [ ] PhotoDetailScreen で左右スワイプで前後の写真に移動できる
- [ ] 戻るとギャラリーに滑らかに戻る
- [ ] メニューボタンからカラーパレットが開ける
- [ ] パレット選択で背景が切り替わる
- [ ] パレット選択がアプリ再起動後も保持される
- [ ] システムのダーク/ライトモードに連動する（ユーザーが固定設定もできる）
- [ ] PhotoDetailScreen に「シェア」ボタンの場所だけ確保（実装は Sprint 3）
- [ ] テストで Clock を差し替えて 24 時間経過のロジックを検証できる

---

## 2. ユーザー体験フロー

```
HomeScreen（撮影画面）
   ├── 左下「泡たち」ボタン → GalleryScreen
   └── 右下「メニュー」ボタン → パレットパネルがスライドアップ

GalleryScreen
   ├── 泡たちが縦スクロールで並ぶ（最新が上）
   │     ├── 現像済み: 写真が中に見える
   │     └── 未現像: 透明で「あと○時間」
   ├── 現像済み泡タップ → 泡割れ演出 → PhotoDetailScreen
   ├── 未現像泡タップ → 軽く揺れる（割れない）
   ├── 左下「ホーム」ボタン → HomeScreen に戻る
   └── 右下「メニュー」ボタン → パレットパネル

PhotoDetailScreen
   ├── 写真フルスクリーン表示 + メモ
   ├── 左右スワイプ → 前後の現像済み写真に切り替え
   ├── メモ右の編集アイコン → インラインで編集可能
   ├── 「シェア」アイコン（Sprint 3 で実装、Sprint 2 はプレースホルダ）
   └── 戻るジェスチャ/ボタン → GalleryScreen に滑らかに戻る
```

**重要な体験設計の意図**:

- ギャラリーは「写真の倉庫」ではなく「空に舞う泡たち」。情報密度より空気感を優先
- 現像前の泡は中身が見えないことがフィルムカメラ的な「待つ楽しみ」を作る
- 泡が割れて写真が出てくる瞬間が、現像という体験のハイライト
- パレットで空の色を変えられることが、自分だけの世界を持つ感覚を作る

---

## 3. 技術的な設計判断

### 3.1 ナビゲーション: Sealed class 拡張 + AnimatedContent

Sprint 1 と同じパターンで `App.kt` の `Screen` sealed class を拡張する。

```kotlin
sealed class Screen {
    object Home : Screen()
    data class Memo(val absoluteImagePath: String) : Screen()
    object Gallery : Screen()                          // NEW
    data class PhotoDetail(val photoId: String) : Screen() // NEW
}
```

画面遷移は `androidx.compose.animation.AnimatedContent` で fade + scale のトランジション。
`navigation-compose` は KMP での安定性と Shared Element Transition の制約により採用しない。

**将来の拡張ポイント**: Sprint 3 で Card 画面が追加されると `App.kt` の sealed class が肥大化するため、Sprint 4 以降で `navigation-compose` または独自 NavController への移行を検討する。

### 3.2 時刻注入: kotlinx.datetime.Clock を直接利用

独自の `Clock` インターフェースは作らず、`kotlinx.datetime.Clock` を Koin 経由で注入する。

```kotlin
// AppModule.kt
import kotlinx.datetime.Clock
single<Clock> { Clock.System }

// DevelopPhotoUseCase.kt
class DevelopPhotoUseCase(
    private val repository: PhotoRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(): List<Photo> =
        repository.findAllOrderByCapturedAtDesc()
            .map { it.withDevelopedFlag(clock.now()) }
}

// テスト
class FakeClock(private val instant: Instant) : Clock {
    override fun now(): Instant = instant
}
```

これによりテスト時は `FakeClock(Instant.parse("2026-05-03T12:00:00Z"))` を渡すだけで 24 時間経過後の挙動を検証できる。

### 3.3 泡のレンダリング

Compose Multiplatform の制約上、CSS のような `border-radius` モーフィングは custom `Shape` の実装が必要で v1 のスコープに対しては過剰。
v1 では以下で「ふわっと揺らぐ泡」を表現する：

- **形状**: `CircleShape` で固定（モーフィング無し）
- **浮遊**: `animateOffsetAsState` で translate を ±8px 程度ゆっくり繰り返す
- **スケール揺らぎ**: `animateFloatAsState` で 1.0〜1.04 を 4〜8 秒周期
- **虹色薄膜**: 半透明グラデーションを `Box` 上に重ねる
- **ハイライト**: 左上から白の `radial gradient` を `Brush` で描画
- **縁の光**: `Modifier.border` または `inset shadow` 風の重ね描画

各泡はサイズ 4 段階（XL=180dp / L=145dp / M=115dp / S=95dp）からランダムに選ぶ（同じ写真には毎回同じサイズ）。
水平オフセットも写真 ID から決定的に算出（毎回同じ位置）。

**将来の拡張ポイント**: より本物らしいシャボン玉表現は Sprint 4 以降の視覚調整で対応。
具体的には：
- Skia シェーダーによる虹色干渉
- border-radius モーフィングの custom Shape 実装
- パーティクル（割れた瞬間の小さな泡）

### 3.4 ギャラリーのスクロール

- `LazyColumn` で泡を縦に並べる
- 各 item は固定の `Box` ではなく、`offset` をスクロール量に応じて補正することで「スクロールに合わせてふわっと舞い上がる」表現
- スクロールオフセットは `LazyListState.firstVisibleItemScrollOffset` から取得し、`Modifier.graphicsLayer { translationY = -scrollOffset * 0.3f }` のように parallax 適用

### 3.5 PhotoDetailScreen の前後ナビゲーション

`androidx.compose.foundation.pager.HorizontalPager` を採用（Compose 1.7.0 で KMP 対応済み）。

- pager に渡すリストは **現像済み写真のみ**（未現像はそもそも見られないので除外）
- 初期ページは `PhotoDetail(photoId)` の `photoId` から決定
- `pageCount` は `developedPhotos.size`
- ページ間アニメーションは Compose 標準

### 3.6 泡割れ演出

タップ → 詳細画面遷移までの 800ms で以下を再生：

1. 0〜200ms: 泡が `scale 1.0 → 1.15` に膨らむ
2. 200〜400ms: `alpha 1.0 → 0.0` でフェードしつつ `scale 1.15 → 0.0` に縮小
3. 400ms 時点で AnimatedContent が PhotoDetailScreen に切替
4. 400〜800ms: 写真が `alpha 0 → 1` + `scale 0.85 → 1.0` でフェードイン

戻る時はこの逆再生。

### 3.7 メモ編集 UX

PhotoDetailScreen のメモエリア:

- 表示時: メモテキスト + 右端に小さな鉛筆アイコン
- 鉛筆タップ: メモが `OutlinedTextField` に切替（インライン編集）
- テキストフィールド下に「保存」「キャンセル」ボタン
- 保存タップ: `PhotoRepository.updateMemo(id, newMemo)` 実行

メモが空のときは「メモなし」とプレースホルダ表示し、鉛筆タップで編集モードに入る。

### 3.8 テーマ管理

#### ダーク/ライトモード

- システムのダーク/ライト設定を `isSystemInDarkTheme()` で取得
- `ThemeMode` enum: `SYSTEM` / `DARK` / `LIGHT`
- ユーザー設定が `SYSTEM` ならシステムに追従、それ以外は固定

#### カラーパレット

6 種類のニュアンスカラーを `enum class SkyPalette` で定義：

| キー | 表示名 | ダーク主色 | ライト主色 |
|------|--------|-----------|-----------|
| NIGHT_SKY | 夜空 | 深い藍紫 | 淡い藤 |
| MIST | 霧海 | 濃い藍 | 霞んだ青灰 |
| DUSK | 夕暮れ | 焦げ茶赤 | 桃橙 |
| KOMOREBI | 木漏れ日 | 深い緑 | 若葉色 |
| AKATSUKI | 暁 | 深い紫紅 | 桜薄紅 |
| SILVER_FOG | 銀霧 | 紺鈍色 | 薄銀鼠 |

各パレットは「ダーク用 RGB 5 色（背景上下 + radial gradient 用 3 色）+ ライト用 RGB 5 色」を持つ data object。

#### 永続化

`com.russhwolf:multiplatform-settings:1.2.0` を導入し、以下を保存：

- `theme_mode`: SYSTEM / DARK / LIGHT
- `sky_palette`: NIGHT_SKY / MIST / DUSK / KOMOREBI / AKATSUKI / SILVER_FOG

`ThemeRepository` を Domain 層に追加し、ViewModel から読み書きする。

#### CompositionLocal

`LocalSkyTheme` という `CompositionLocal<SkyTheme>` を `App.kt` で提供し、すべての画面が現在のパレット色にアクセスできるようにする。

```kotlin
data class SkyTheme(
    val palette: SkyPalette,
    val mode: ThemeMode,
    val isDark: Boolean,        // 解決後の実値
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val gradientA: Color,
    val gradientB: Color,
    val gradientC: Color,
    val textPrimary: Color,
    val textSecondary: Color,
)

val LocalSkyTheme = compositionLocalOf<SkyTheme> { error("not provided") }
```

**将来の拡張ポイント**:
- パレット種類の追加
- ユーザー定義パレット（カスタムカラーピッカー）
- 時間帯による自動切替（朝・昼・夕・夜）
- 季節による自動切替

### 3.9 シェアボタン（Sprint 3 用プレースホルダ）

PhotoDetailScreen の右上に共有アイコンを配置するが、タップ時は何もしない（または `Toast/SnackBar` で「Sprint 3 で実装予定」を表示）。
位置とサイズは Sprint 3 で実装する `ShareService` を呼ぶ実装を当てはめても破綻しないことを確認しておく。

---

## 4. データモデルと永続化の追加

### 4.1 SQLDelight クエリ追加（Photo.sq）

```sql
-- 既存に追加
selectAllOrderByCapturedAtDesc:
SELECT * FROM Photo
ORDER BY captured_at DESC;

updateMemo:
UPDATE Photo SET memo = ? WHERE id = ?;
```

スキーマ自体は変更しないため、マイグレーションは不要。

### 4.2 PhotoRepository インターフェース拡張

```kotlin
interface PhotoRepository {
    // 既存
    suspend fun save(photo: Photo)
    suspend fun findById(id: String): Photo?
    suspend fun findByLocalDate(date: LocalDate): List<Photo>
    suspend fun findDevelopedAsOf(now: Instant): List<Photo>
    suspend fun delete(id: String)

    // 追加
    suspend fun findAllOrderByCapturedAtDesc(): List<Photo>
    suspend fun updateMemo(id: String, memo: String)
}
```

### 4.3 Photo モデルの追加メソッド

```kotlin
data class Photo(
    // 既存フィールド
    val id: String,
    val capturedAt: Instant,
    val developedAt: Instant,
    val imagePath: String,
    val memo: String,
    val areaLabel: String
) {
    fun isDeveloped(now: Instant): Boolean = now >= developedAt

    // 追加: 残り時間（未現像のみ）
    fun remainingUntilDeveloped(now: Instant): Duration =
        if (isDeveloped(now)) Duration.ZERO
        else developedAt - now
}
```

### 4.4 ThemeRepository（新規）

```kotlin
// domain/repository/ThemeRepository.kt
interface ThemeRepository {
    fun observeThemeMode(): StateFlow<ThemeMode>
    suspend fun setThemeMode(mode: ThemeMode)
    fun observeSkyPalette(): StateFlow<SkyPalette>
    suspend fun setSkyPalette(palette: SkyPalette)
}

// data/repository/SettingsThemeRepository.kt
class SettingsThemeRepository(private val settings: Settings) : ThemeRepository {
    // multiplatform-settings で実装
}
```

---

## 5. ファイル構成（追加・変更）

```
composeApp/src/
├── commonMain/kotlin/io/awairo/
│   ├── App.kt                                       # Screen sealed class 拡張、SkyTheme 提供
│   ├── domain/
│   │   ├── model/
│   │   │   ├── Photo.kt                             # 既存（remainingUntilDeveloped 追加）
│   │   │   ├── SkyPalette.kt                        # NEW
│   │   │   └── ThemeMode.kt                         # NEW
│   │   ├── repository/
│   │   │   ├── PhotoRepository.kt                   # 既存（メソッド追加）
│   │   │   └── ThemeRepository.kt                   # NEW
│   │   └── usecase/
│   │       └── DevelopPhotoUseCase.kt               # NEW
│   ├── data/
│   │   ├── local/
│   │   │   └── (Photo.sq にクエリ追加)
│   │   └── repository/
│   │       ├── LocalPhotoRepository.kt              # 既存（メソッド追加）
│   │       └── SettingsThemeRepository.kt           # NEW
│   ├── presentation/
│   │   ├── component/
│   │   │   ├── BubbleGalleryItem.kt                 # NEW
│   │   │   ├── PaletteSheet.kt                      # NEW
│   │   │   └── BottomActionBar.kt                   # NEW（HomeScreen/Galleryで共用）
│   │   ├── screen/
│   │   │   ├── HomeScreen.kt                        # 既存（BottomActionBar 配置）
│   │   │   ├── MemoScreen.kt                        # 既存
│   │   │   ├── GalleryScreen.kt                     # NEW
│   │   │   └── PhotoDetailScreen.kt                 # NEW
│   │   ├── viewmodel/
│   │   │   ├── HomeViewModel.kt                     # 既存
│   │   │   ├── MemoViewModel.kt                     # 既存
│   │   │   ├── GalleryViewModel.kt                  # NEW
│   │   │   ├── PhotoDetailViewModel.kt              # NEW
│   │   │   └── ThemeViewModel.kt                    # NEW
│   │   └── theme/
│   │       └── SkyTheme.kt                          # NEW
│   └── di/
│       └── AppModule.kt                             # 既存（Clock, ThemeRepository, 新ViewModel追加）
│
├── androidMain/kotlin/io/awairo/di/
│   └── AndroidModule.kt                             # 既存（Settings 実装注入）
└── iosMain/kotlin/io/awairo/di/
    └── IosModule.kt                                 # 既存（Settings 実装注入）
```

---

## 6. テスト計画

### 6.1 単体テスト（commonTest）

| 対象 | 検証内容 |
|------|---------|
| `DevelopPhotoUseCase` | Clock を差し替え、24 時間前の撮影が現像済みになることを検証 |
| `Photo.isDeveloped` | 24h 境界の前後で正しく判定 |
| `Photo.remainingUntilDeveloped` | 残り時間の計算（未現像/現像済み） |
| `SettingsThemeRepository` | パレット保存・読み出しが永続化される |

### 6.2 統合テスト（androidUnitTest / iosTest はスコープ外）

UI 統合テストは Sprint 2 ではスコープ外。実機/シミュレータでのマニュアル動作確認のみ。

### 6.3 マニュアル動作確認

`docs/manual/` にチェックリストを追加：

- [ ] 新規撮影直後はギャラリーで未現像表示
- [ ] 端末時刻を 24 時間進めて再起動 → 現像済みに切り替わる
- [ ] 泡タップ → 詳細遷移 → スワイプ → 戻る、すべてスムーズ
- [ ] メモ編集 → 保存 → 戻って再度開いてメモが反映されている
- [ ] パレット切替 → アプリ再起動 → 同じパレット
- [ ] ダーク固定/ライト固定/システム連動の 3 モードが正しく動作

---

## 7. 依存関係の追加

`gradle/libs.versions.toml` に追加：

```toml
[versions]
multiplatform-settings = "1.2.0"

[libraries]
multiplatform-settings = { module = "com.russhwolf:multiplatform-settings", version.ref = "multiplatform-settings" }
multiplatform-settings-coroutines = { module = "com.russhwolf:multiplatform-settings-coroutines", version.ref = "multiplatform-settings" }
```

`composeApp/build.gradle.kts` の `commonMain` に追加：

```kotlin
implementation(libs.multiplatform-settings)
implementation(libs.multiplatform-settings-coroutines)
```

Android/iOS 個別の追加実装は不要（マルチプラットフォーム対応済み）。

---

## 8. リスクと対応

| リスク | 影響 | 対応 |
|--------|------|------|
| Compose Animation の iOS パフォーマンス低下 | 60fps 出ない | LazyColumn で off-screen は描画しない、wobble は 1 アニメーションのみ |
| HorizontalPager の iOS 動作 | スワイプ動作不安定 | Compose 1.7.0 で動作実績あり、念のため早期に確認 |
| multiplatform-settings の Kotlin 2.0.21 互換性 | ビルドエラー | 1.2.0 は Kotlin 2.0 対応済み（公式ドキュメント確認済み） |
| 24 時間経過後の自動更新 | アプリ起動中に時刻が経過してもギャラリー上は未現像のまま | `GalleryViewModel` で 1 分間隔でリフレッシュ（Flow + delay）|

---

## 9. リリース可能性チェック（共通要件）

Sprint 終了時に以下を満たすこと：

- [ ] Android: `./gradlew assembleRelease` で APK が生成できる
- [ ] iOS: Xcode で Release ビルドがシミュレータで動作する
- [ ] HomeScreen から GalleryScreen を経て PhotoDetailScreen に到達でき、戻ってこられる
- [ ] 機能が中途半端な画面が残っていない
- [ ] CI が green
- [ ] シミュレータ（または実機）で動作確認済み

---

## 10. 拡張ポイント（Sprint 4+ 候補）

仕様書に明示しておくことで、後から差し込みやすくする：

| 拡張点 | 用途 |
|--------|------|
| 個別の泡の色を変更 | 「お気に入り」の写真の泡だけ別の色にできる |
| 高度な泡シェーダー | Skia シェーダーで本物の薄膜干渉色を再現 |
| パレット種類の追加 | 季節パレット、地域パレット、自作パレット |
| 時間帯/季節による自動切替 | 朝・昼・夕・夜でパレットが自動変化 |
| 泡の割れアニメーションの強化 | 小さな泡パーティクルが飛び散る |
| 写真の検索・フィルタ | エリア別・期間別の絞り込み |
| 統計ビュー | 月単位の撮影履歴を別ビューで |

---

## 11. 未決定事項（Sprint 3 で決める）

- `ShareService` の具体的なシェアコンテンツ（写真のみ / 写真+メモ / フォトカード）
- フォトカードのテンプレートとレイアウト
- メモの最大文字数の表示・制限の UI
