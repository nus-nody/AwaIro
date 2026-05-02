# Sprint 2 — Develop（現像する） Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 24時間後に「現像」される泡たちのギャラリー、タップで泡が割れて写真とメモが見える詳細画面、システム連動のダーク/ライトモードと6色のカラーパレットを実装する。

**Architecture:** 既存 `Screen` sealed class を `Gallery` / `PhotoDetail` で拡張し `AnimatedContent` で遷移させる（navigation-compose は不採用）。時刻は `kotlinx.datetime.Clock` を Koin 経由で注入し `DevelopPhotoUseCase` でテスト可能にする。テーマは `multiplatform-settings` で永続化し `CompositionLocal<SkyTheme>` で全画面に提供。詳細画面の前後遷移は `HorizontalPager` を使用。

**Tech Stack:** Compose Multiplatform 1.7.0、kotlinx-datetime 0.6.1、`com.russhwolf:multiplatform-settings:1.2.0`（新規）、`androidx.compose.foundation.pager.HorizontalPager`、Koin 4.0、SQLDelight 2.0.2、kotlinx-coroutines-test（既存）

---

## ベースライン確認（実装開始前に必ず実行）

### 1. ワークツリー作成

```bash
cd /Users/nodayouta/Documents/code/AwaIro

# main の最新を取得
git fetch origin
git checkout main
git pull origin main

# 既存の dirty state がある場合は別ブランチに退避してから worktree を作る
# （現状 gradle.properties / libs.versions.toml / gradle-wrapper.properties / project.pbxproj に
#  Kotlin/AGP アップグレードの未コミット変更がある可能性がある）
git status

# worktree 作成
git worktree add .worktrees/sprint2-develop -b feature/sprint2-develop
cd .worktrees/sprint2-develop
```

### 2. ベースライン緑

```bash
./gradlew :composeApp:assembleDebug
# → BUILD SUCCESSFUL を確認

./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
# → BUILD SUCCESSFUL を確認
```

両方が緑になってから Task 1 へ進む。失敗する場合は Sprint 1 のリリース時点（タグ `v0.2.0-sprint1`）からの差分が原因の可能性があるので、まずそれを解消する。

### 3. 読むべきファイル

- `docs/superpowers/specs/2026-05-02-sprint-2-develop-design.md` — 本計画の設計書（必読）
- `docs/superpowers/specs/2026-04-24-awairo-design.md` — 全体設計（参考）
- `composeApp/src/commonMain/kotlin/io/awairo/App.kt` — 既存 Screen sealed class
- `composeApp/src/commonMain/kotlin/io/awairo/data/repository/LocalPhotoRepository.kt` — Repository 拡張の参考
- `composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt` — DI 登録の参考
- `composeApp/src/commonMain/sqldelight/io/awairo/db/Photo.sq` — SQLDelight クエリ追加先

---

## Task 1: 依存関係追加（multiplatform-settings）

**Files:**
- Modify: `gradle/libs.versions.toml`
- Modify: `composeApp/build.gradle.kts`

- [ ] **Step 1: libs.versions.toml にバージョンとライブラリを追加**

`gradle/libs.versions.toml` の `[versions]` セクションに追加:

```toml
multiplatform-settings = "1.2.0"
```

`[libraries]` セクションに追加:

```toml
multiplatform-settings = { module = "com.russhwolf:multiplatform-settings", version.ref = "multiplatform-settings" }
multiplatform-settings-coroutines = { module = "com.russhwolf:multiplatform-settings-coroutines", version.ref = "multiplatform-settings" }
```

- [ ] **Step 2: build.gradle.kts の commonMain dependencies に追加**

`composeApp/build.gradle.kts` の `sourceSets { commonMain.dependencies { ... } }` ブロックの末尾（`// Sprint 1 追加` の後）に以下を追加:

```kotlin
            // Sprint 2 追加
            implementation(libs.multiplatform.settings)
            implementation(libs.multiplatform.settings.coroutines)
```

- [ ] **Step 3: ビルドが通ることを確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

もし `multiplatform-settings 1.2.0` が現在の Kotlin バージョンと非互換でビルドエラーになる場合は、`gradle/libs.versions.toml` で `multiplatform-settings = "1.3.0"` に上げて再試行する。

- [ ] **Step 4: コミット**

```bash
git add gradle/libs.versions.toml composeApp/build.gradle.kts
git commit -m "chore(sprint2): add multiplatform-settings dependency for theme persistence"
```

---

## Task 2: SQLDelight クエリ追加

**Files:**
- Modify: `composeApp/src/commonMain/sqldelight/io/awairo/db/Photo.sq`

- [ ] **Step 1: Photo.sq の末尾に 2 つのクエリを追加**

`composeApp/src/commonMain/sqldelight/io/awairo/db/Photo.sq` の最後（`deleteById` の後）に追加:

```sql
selectAllOrderByCapturedAtDesc:
SELECT * FROM Photo
ORDER BY captured_at DESC;

updateMemo:
UPDATE Photo SET memo = ? WHERE id = ?;
```

- [ ] **Step 2: SQLDelight が生成するコードを確認**

```bash
./gradlew :composeApp:generateCommonMainAwaIroDatabaseInterface
```

Expected: `BUILD SUCCESSFUL`、`composeApp/build/generated/sqldelight/code/AwaIroDatabase/commonMain/io/awairo/db/PhotoQueries.kt` に `selectAllOrderByCapturedAtDesc` と `updateMemo` メソッドが生成されていること（grep で確認）:

```bash
grep -E "selectAllOrderByCapturedAtDesc|updateMemo" composeApp/build/generated/sqldelight/code/AwaIroDatabase/commonMain/io/awairo/db/PhotoQueries.kt
```

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/sqldelight/io/awairo/db/Photo.sq
git commit -m "feat(sprint2): add selectAllOrderByCapturedAtDesc and updateMemo SQL queries"
```

---

## Task 3: Photo モデル拡張（残り時間計算）

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/domain/model/Photo.kt`
- Create: `composeApp/src/commonTest/kotlin/io/awairo/domain/model/PhotoTest.kt`

- [ ] **Step 1: Photo.kt に `remainingUntilDeveloped` を追加**

`composeApp/src/commonMain/kotlin/io/awairo/domain/model/Photo.kt` を以下に置き換え:

```kotlin
package io.awairo.domain.model

import kotlinx.datetime.Instant
import kotlin.time.Duration

data class Photo(
    val id: String,
    val capturedAt: Instant,
    val developedAt: Instant,
    val imagePath: String,
    val memo: String,
    val areaLabel: String
) {
    fun isDeveloped(now: Instant): Boolean = now >= developedAt

    /**
     * 現像までの残り時間。現像済みの場合は [Duration.ZERO]。
     */
    fun remainingUntilDeveloped(now: Instant): Duration =
        if (isDeveloped(now)) Duration.ZERO else developedAt - now
}
```

- [ ] **Step 2: PhotoTest.kt を作成**

`composeApp/src/commonTest/kotlin/io/awairo/domain/model/PhotoTest.kt` を新規作成:

```kotlin
package io.awairo.domain.model

import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.hours

class PhotoTest {

    private fun makePhoto(capturedAt: Instant, developedAt: Instant) = Photo(
        id = "test",
        capturedAt = capturedAt,
        developedAt = developedAt,
        imagePath = "/tmp/test.jpg",
        memo = "",
        areaLabel = "test"
    )

    @Test
    fun isDeveloped_returnsTrue_whenNowIsAfterDevelopedAt() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-03T00:00:01Z")
        assertTrue(photo.isDeveloped(now))
    }

    @Test
    fun isDeveloped_returnsTrue_atExactBoundary() {
        val developedAt = Instant.parse("2026-05-03T00:00:00Z")
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = developedAt
        )
        assertTrue(photo.isDeveloped(developedAt))
    }

    @Test
    fun isDeveloped_returnsFalse_whenNowIsBeforeDevelopedAt() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-02T23:59:59Z")
        assertFalse(photo.isDeveloped(now))
    }

    @Test
    fun remainingUntilDeveloped_returnsZero_whenAlreadyDeveloped() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-04T00:00:00Z")
        assertEquals(kotlin.time.Duration.ZERO, photo.remainingUntilDeveloped(now))
    }

    @Test
    fun remainingUntilDeveloped_returnsCorrectDuration_whenNotDeveloped() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-02T18:00:00Z")
        assertEquals(6.hours, photo.remainingUntilDeveloped(now))
    }
}
```

- [ ] **Step 3: テストを実行して全 5 件が pass することを確認**

```bash
./gradlew :composeApp:jvmTest --tests "io.awairo.domain.model.PhotoTest"
# JVM テストターゲットがない場合は androidUnitTest:
./gradlew :composeApp:testDebugUnitTest --tests "io.awairo.domain.model.PhotoTest"
```

Expected: `5 tests, 0 failures`

- [ ] **Step 4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/model/Photo.kt \
        composeApp/src/commonTest/kotlin/io/awairo/domain/model/PhotoTest.kt
git commit -m "feat(sprint2): add remainingUntilDeveloped to Photo with tests"
```

---

## Task 4: PhotoRepository 拡張

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/domain/repository/PhotoRepository.kt`
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/data/repository/LocalPhotoRepository.kt`

- [ ] **Step 1: インターフェースに 2 メソッドを追加**

`composeApp/src/commonMain/kotlin/io/awairo/domain/repository/PhotoRepository.kt` を以下に置き換え:

```kotlin
package io.awairo.domain.repository

import io.awairo.domain.model.Photo
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

interface PhotoRepository {
    suspend fun save(photo: Photo)
    suspend fun findById(id: String): Photo?
    suspend fun findByLocalDate(date: LocalDate): List<Photo>
    suspend fun findDevelopedAsOf(now: Instant): List<Photo>
    suspend fun delete(id: String)

    /** 全件を撮影日時の新しい順で返す（現像済み・未現像どちらも含む）。 */
    suspend fun findAllOrderByCapturedAtDesc(): List<Photo>

    /** 指定 ID の写真のメモを更新する。 */
    suspend fun updateMemo(id: String, memo: String)
}
```

- [ ] **Step 2: LocalPhotoRepository に実装を追加**

`composeApp/src/commonMain/kotlin/io/awairo/data/repository/LocalPhotoRepository.kt` の `delete(id: String)` メソッドの**後**に以下を追加（クラス内の他のメソッドはそのまま）:

```kotlin
    override suspend fun findAllOrderByCapturedAtDesc(): List<Photo> =
        database.photoQueries.selectAllOrderByCapturedAtDesc()
            .executeAsList().map { it.toDomain() }

    override suspend fun updateMemo(id: String, memo: String) {
        database.photoQueries.updateMemo(memo = memo, id = id)
    }
```

- [ ] **Step 3: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/repository/PhotoRepository.kt \
        composeApp/src/commonMain/kotlin/io/awairo/data/repository/LocalPhotoRepository.kt
git commit -m "feat(sprint2): extend PhotoRepository with findAllOrderByCapturedAtDesc and updateMemo"
```

---

## Task 5: DevelopPhotoUseCase（TDD）

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCase.kt`
- Create: `composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCaseTest.kt`

- [ ] **Step 1: 失敗するテストを書く**

`composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCaseTest.kt` を新規作成:

```kotlin
package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class FakeClock(private val instant: Instant) : Clock {
    override fun now(): Instant = instant
}

private class FakePhotoRepository(private val photos: List<Photo>) : PhotoRepository {
    override suspend fun save(photo: Photo) = error("not used")
    override suspend fun findById(id: String): Photo? = photos.firstOrNull { it.id == id }
    override suspend fun findByLocalDate(date: LocalDate): List<Photo> = error("not used")
    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> = error("not used")
    override suspend fun delete(id: String) = error("not used")
    override suspend fun findAllOrderByCapturedAtDesc(): List<Photo> = photos
    override suspend fun updateMemo(id: String, memo: String) = error("not used")
}

class DevelopPhotoUseCaseTest {

    private fun photo(id: String, captured: Instant) = Photo(
        id = id,
        capturedAt = captured,
        developedAt = captured.plus(kotlin.time.Duration.parse("PT24H")),
        imagePath = "/tmp/$id.jpg",
        memo = "",
        areaLabel = ""
    )

    @Test
    fun returnsAllPhotosInOrder_withDevelopedFlagsResolved() = runTest {
        val older = photo("a", Instant.parse("2026-05-01T00:00:00Z"))      // 25h前
        val newer = photo("b", Instant.parse("2026-05-02T00:00:00Z"))      // 1h前
        val repo = FakePhotoRepository(listOf(newer, older))
        val now = Instant.parse("2026-05-02T01:00:00Z")
        val useCase = DevelopPhotoUseCase(repo, FakeClock(now))

        val result = useCase()

        assertEquals(2, result.size)
        assertEquals("b", result[0].photo.id)  // 新しい順を維持
        assertFalse(result[0].isDeveloped)     // 1h 前撮影 → 未現像
        assertEquals("a", result[1].photo.id)
        assertTrue(result[1].isDeveloped)      // 25h 前撮影 → 現像済み
    }

    @Test
    fun emptyList_whenNoPhotos() = runTest {
        val useCase = DevelopPhotoUseCase(
            FakePhotoRepository(emptyList()),
            FakeClock(Instant.parse("2026-05-02T00:00:00Z"))
        )
        assertTrue(useCase().isEmpty())
    }
}
```

- [ ] **Step 2: テスト実行 → コンパイルエラーで失敗することを確認**

```bash
./gradlew :composeApp:testDebugUnitTest --tests "io.awairo.domain.usecase.DevelopPhotoUseCaseTest"
```

Expected: `Unresolved reference: DevelopPhotoUseCase`（クラス未定義）

- [ ] **Step 3: 最小実装を書く**

`composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCase.kt` を新規作成:

```kotlin
package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlin.time.Duration

/**
 * 全写真を新しい順で取得し、各写真の現像状態を `now` 基準で解決して返す。
 */
class DevelopPhotoUseCase(
    private val repository: PhotoRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(): List<DevelopedPhoto> {
        val now = clock.now()
        return repository.findAllOrderByCapturedAtDesc().map { photo ->
            DevelopedPhoto(
                photo = photo,
                isDeveloped = photo.isDeveloped(now),
                remaining = photo.remainingUntilDeveloped(now)
            )
        }
    }
}

/** 表示時点で解決済みの「現像状態付き写真」。 */
data class DevelopedPhoto(
    val photo: Photo,
    val isDeveloped: Boolean,
    val remaining: Duration
) {
    val id: String get() = photo.id
}
```

- [ ] **Step 4: テスト再実行 → 全 2 件 pass することを確認**

```bash
./gradlew :composeApp:testDebugUnitTest --tests "io.awairo.domain.usecase.DevelopPhotoUseCaseTest"
```

Expected: `2 tests, 0 failures`

- [ ] **Step 5: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCase.kt \
        composeApp/src/commonTest/kotlin/io/awairo/domain/usecase/DevelopPhotoUseCaseTest.kt
git commit -m "feat(sprint2): add DevelopPhotoUseCase with Clock injection (TDD)"
```

---

## Task 6: テーマ列挙型と SkyTheme カラー定義

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/model/ThemeMode.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/model/SkyPalette.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/theme/SkyTheme.kt`

- [ ] **Step 1: ThemeMode enum を作成**

`composeApp/src/commonMain/kotlin/io/awairo/domain/model/ThemeMode.kt`:

```kotlin
package io.awairo.domain.model

enum class ThemeMode { SYSTEM, DARK, LIGHT }
```

- [ ] **Step 2: SkyPalette enum を作成**

`composeApp/src/commonMain/kotlin/io/awairo/domain/model/SkyPalette.kt`:

```kotlin
package io.awairo.domain.model

enum class SkyPalette(val displayName: String) {
    NIGHT_SKY("夜空"),
    MIST("霧海"),
    DUSK("夕暮れ"),
    KOMOREBI("木漏れ日"),
    AKATSUKI("暁"),
    SILVER_FOG("銀霧"),
}
```

- [ ] **Step 3: SkyTheme（CompositionLocal + 色解決）を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/theme/SkyTheme.kt`:

```kotlin
package io.awairo.presentation.theme

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode

data class SkyTheme(
    val palette: SkyPalette,
    val mode: ThemeMode,
    val isDark: Boolean,
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val gradientA: Color,
    val gradientB: Color,
    val gradientC: Color,
    val textPrimary: Color,
    val textSecondary: Color,
)

val LocalSkyTheme = compositionLocalOf<SkyTheme> {
    error("SkyTheme not provided. Wrap your composable in CompositionLocalProvider(LocalSkyTheme provides ...)")
}

/**
 * 現在のパレット・ダークモードフラグから [SkyTheme] を解決する。
 */
fun resolveSkyTheme(palette: SkyPalette, mode: ThemeMode, isSystemDark: Boolean): SkyTheme {
    val dark = when (mode) {
        ThemeMode.SYSTEM -> isSystemDark
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
    }
    val colors = if (dark) darkColorsFor(palette) else lightColorsFor(palette)
    return SkyTheme(
        palette = palette,
        mode = mode,
        isDark = dark,
        backgroundTop = colors.bgTop,
        backgroundBottom = colors.bgBottom,
        gradientA = colors.gradA,
        gradientB = colors.gradB,
        gradientC = colors.gradC,
        textPrimary = colors.textPrimary,
        textSecondary = colors.textSecondary,
    )
}

private data class PaletteColors(
    val bgTop: Color, val bgBottom: Color,
    val gradA: Color, val gradB: Color, val gradC: Color,
    val textPrimary: Color, val textSecondary: Color,
)

private fun darkColorsFor(p: SkyPalette): PaletteColors = when (p) {
    SkyPalette.NIGHT_SKY -> PaletteColors(
        Color(0xFF03030E), Color(0xFF06061A),
        Color(0xD9190837), Color(0xCC081437), Color(0x8C041E16),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.MIST -> PaletteColors(
        Color(0xFF070C12), Color(0xFF0A1220),
        Color(0xD908193C), Color(0xCC052832), Color(0x8C031E2D),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.DUSK -> PaletteColors(
        Color(0xFF0E0608), Color(0xFF1C0A0A),
        Color(0xD9370C08), Color(0xCC280F05), Color(0x8C0A061E),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.KOMOREBI -> PaletteColors(
        Color(0xFF040C06), Color(0xFF061410),
        Color(0xD9062312), Color(0xCC08321E), Color(0x801E2808),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.AKATSUKI -> PaletteColors(
        Color(0xFF0A0608), Color(0xFF180A14),
        Color(0xD9320828), Color(0xCC0C0837), Color(0x8C18081E),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.SILVER_FOG -> PaletteColors(
        Color(0xFF080A10), Color(0xFF10121E),
        Color(0xD9141932), Color(0xCC1E233C), Color(0x8C12172A),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
}

private fun lightColorsFor(p: SkyPalette): PaletteColors = when (p) {
    SkyPalette.NIGHT_SKY -> PaletteColors(
        Color(0xFFECEAF4), Color(0xFFDDDAF0),
        Color(0x40A08CDC), Color(0x338CA0E6), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.MIST -> PaletteColors(
        Color(0xFFEAF0F4), Color(0xFFD8E8F0),
        Color(0x478CB4D2), Color(0x38A0C8DC), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.DUSK -> PaletteColors(
        Color(0xFFF8EDE4), Color(0xFFF0DDD0),
        Color(0x52F0A064), Color(0x38DC7850), Color(0x29B464A0),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.KOMOREBI -> PaletteColors(
        Color(0xFFEEF4E8), Color(0xFFE0ECDA),
        Color(0x478CC864), Color(0x38B4DC78), Color(0x2EDCC850),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.AKATSUKI -> PaletteColors(
        Color(0xFFF8EAF0), Color(0xFFF0D8E8),
        Color(0x47DC8CB4), Color(0x33B48CDC), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.SILVER_FOG -> PaletteColors(
        Color(0xFFEEEFF4), Color(0xFFE0E2EC),
        Color(0x4DB4B9D2), Color(0x38A0A5C8), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
}
```

- [ ] **Step 4: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/model/ThemeMode.kt \
        composeApp/src/commonMain/kotlin/io/awairo/domain/model/SkyPalette.kt \
        composeApp/src/commonMain/kotlin/io/awairo/presentation/theme/SkyTheme.kt
git commit -m "feat(sprint2): add ThemeMode/SkyPalette enums and SkyTheme color resolver"
```

---

## Task 7: ThemeRepository（multiplatform-settings）

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/repository/ThemeRepository.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/data/repository/SettingsThemeRepository.kt`

- [ ] **Step 1: ThemeRepository インターフェース作成**

`composeApp/src/commonMain/kotlin/io/awairo/domain/repository/ThemeRepository.kt`:

```kotlin
package io.awairo.domain.repository

import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import kotlinx.coroutines.flow.StateFlow

interface ThemeRepository {
    fun observeThemeMode(): StateFlow<ThemeMode>
    suspend fun setThemeMode(mode: ThemeMode)
    fun observeSkyPalette(): StateFlow<SkyPalette>
    suspend fun setSkyPalette(palette: SkyPalette)
}
```

- [ ] **Step 2: SettingsThemeRepository 実装作成**

`composeApp/src/commonMain/kotlin/io/awairo/data/repository/SettingsThemeRepository.kt`:

```kotlin
package io.awairo.data.repository

import com.russhwolf.settings.Settings
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import io.awairo.domain.repository.ThemeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SettingsThemeRepository(
    private val settings: Settings
) : ThemeRepository {

    private val mode = MutableStateFlow(loadMode())
    private val palette = MutableStateFlow(loadPalette())

    override fun observeThemeMode(): StateFlow<ThemeMode> = mode.asStateFlow()

    override suspend fun setThemeMode(mode: ThemeMode) {
        settings.putString(KEY_MODE, mode.name)
        this.mode.value = mode
    }

    override fun observeSkyPalette(): StateFlow<SkyPalette> = palette.asStateFlow()

    override suspend fun setSkyPalette(palette: SkyPalette) {
        settings.putString(KEY_PALETTE, palette.name)
        this.palette.value = palette
    }

    private fun loadMode(): ThemeMode = settings.getStringOrNull(KEY_MODE)
        ?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() }
        ?: ThemeMode.SYSTEM

    private fun loadPalette(): SkyPalette = settings.getStringOrNull(KEY_PALETTE)
        ?.let { runCatching { SkyPalette.valueOf(it) }.getOrNull() }
        ?: SkyPalette.NIGHT_SKY

    companion object {
        private const val KEY_MODE = "theme_mode"
        private const val KEY_PALETTE = "sky_palette"
    }
}
```

- [ ] **Step 3: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/repository/ThemeRepository.kt \
        composeApp/src/commonMain/kotlin/io/awairo/data/repository/SettingsThemeRepository.kt
git commit -m "feat(sprint2): add ThemeRepository backed by multiplatform-settings"
```

---

## Task 8: ThemeViewModel + DI 配線

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/ThemeViewModel.kt`
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt`
- Modify: `composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt`
- Modify: `composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt`

- [ ] **Step 1: ThemeViewModel 作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/ThemeViewModel.kt`:

```kotlin
package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import io.awairo.domain.repository.ThemeRepository
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class ThemeViewModel(
    private val repository: ThemeRepository
) : ViewModel() {

    val themeMode: StateFlow<ThemeMode> = repository.observeThemeMode()
    val skyPalette: StateFlow<SkyPalette> = repository.observeSkyPalette()

    fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch { repository.setThemeMode(mode) }
    }

    fun setSkyPalette(palette: SkyPalette) {
        viewModelScope.launch { repository.setSkyPalette(palette) }
    }
}
```

- [ ] **Step 2: AppModule.kt に DI を追加（この時点で存在するものだけ）**

`composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt` を以下に置き換え:

```kotlin
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.data.repository.SettingsThemeRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.repository.ThemeRepository
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.RecordPhotoUseCase
import io.awairo.presentation.viewmodel.HomeViewModel
import io.awairo.presentation.viewmodel.MemoViewModel
import io.awairo.presentation.viewmodel.ThemeViewModel
import kotlinx.datetime.Clock
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

fun appModule() = module {
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }
    // Sprint 1
    factory { RecordPhotoUseCase(get()) }
    viewModel { HomeViewModel(get()) }
    viewModel { MemoViewModel(get()) }
    // Sprint 2
    single<Clock> { Clock.System }
    single<ThemeRepository> { SettingsThemeRepository(get()) }
    factory { DevelopPhotoUseCase(get(), get()) }
    viewModel { ThemeViewModel(get()) }
    // GalleryViewModel と PhotoDetailViewModel は Task 13 / Task 14 で追加する
}
```

- [ ] **Step 3: AndroidModule.kt に Settings を追加**

`composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt` を以下に置き換え:

```kotlin
package io.awairo.di

import com.russhwolf.settings.Settings
import com.russhwolf.settings.SharedPreferencesSettings
import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

fun androidModule() = module {
    single { DatabaseFactory(androidContext()) }
    // Sprint 1
    single { CameraController(androidContext()) }
    // Sprint 2
    single<Settings> {
        val prefs = androidContext().getSharedPreferences("awa_iro_prefs", android.content.Context.MODE_PRIVATE)
        SharedPreferencesSettings(prefs)
    }
}
```

- [ ] **Step 4: IosModule.kt に Settings を追加**

`composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt` を以下に置き換え:

```kotlin
package io.awairo.di

import com.russhwolf.settings.NSUserDefaultsSettings
import com.russhwolf.settings.Settings
import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.core.context.startKoin
import org.koin.dsl.module
import platform.Foundation.NSUserDefaults

fun iosModule() = module {
    single { DatabaseFactory() }
    // Sprint 1
    single { CameraController() }
    // Sprint 2
    single<Settings> { NSUserDefaultsSettings(NSUserDefaults.standardUserDefaults) }
}

fun initKoinForIos() {
    startKoin {
        modules(iosModule(), appModule())
    }
}
```

- [ ] **Step 5: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 6: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/ThemeViewModel.kt \
        composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt \
        composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt \
        composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt
git commit -m "feat(sprint2): wire Clock, ThemeRepository, Settings into Koin DI"
```

---

## Task 9: BottomActionBar コンポーネント

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BottomActionBar.kt`

- [ ] **Step 1: BottomActionBar を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BottomActionBar.kt`:

```kotlin
package io.awairo.presentation.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.clickable
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.awairo.presentation.theme.LocalSkyTheme

/**
 * 画面下部の左右アクションボタンバー。HomeScreen と GalleryScreen で共用。
 */
@Composable
fun BottomActionBar(
    leftLabel: String,
    leftIcon: String,        // 絵文字またはシンボル文字。後で SVG に置換可能
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
            contentAlignment = Alignment.Center
        ) {
            Text(text = icon, fontSize = 20.sp, color = color)
        }
        Text(text = label, fontSize = 10.sp, color = color.copy(alpha = 0.7f))
    }
}
```

- [ ] **Step 2: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BottomActionBar.kt
git commit -m "feat(sprint2): add BottomActionBar component"
```

---

## Task 10: PaletteSheet コンポーネント

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/component/PaletteSheet.kt`

- [ ] **Step 1: PaletteSheet を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/component/PaletteSheet.kt`:

```kotlin
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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
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
    val panelBg = if (theme.isDark)
        Color(0xEE060614)
    else
        Color(0xF6F8F5F0)

    AnimatedVisibility(
        visible = visible,
        enter = expandVertically() + fadeIn(),
        exit  = shrinkVertically() + fadeOut(),
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
                modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp),
            ) {
                SkyPalette.values().forEach { p ->
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
                ThemeMode.values().forEach { m ->
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
    // 簡易プレビュー: パレットのダーク版/ライト版の bgTop と gradA で radial 風に
    val sample = resolveSkyTheme(palette, ThemeMode.SYSTEM, isSystemDark = isDark)
    val brush = Brush.radialGradient(
        colors = listOf(sample.gradA, sample.backgroundTop)
    )
    val ringColor = if (selected) Color(0xCCFFFFFF) else Color.Transparent
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        androidx.compose.foundation.layout.Box(
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
    val border = if (selected) textColor.copy(alpha = 0.6f) else textColor.copy(alpha = 0.18f)
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(20.dp))
            .border(1.dp, border, androidx.compose.foundation.shape.RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text(text = label, fontSize = 11.sp, color = textColor)
    }
}
```

- [ ] **Step 2: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/component/PaletteSheet.kt
git commit -m "feat(sprint2): add PaletteSheet component for palette + mode selection"
```

---

## Task 11: BubbleGalleryItem コンポーネント

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleGalleryItem.kt`

- [ ] **Step 1: BubbleGalleryItem を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleGalleryItem.kt`:

```kotlin
package io.awairo.presentation.component

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import coil3.ImageLoader
import coil3.compose.LocalPlatformContext
import androidx.compose.runtime.remember
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
    val sizeDp = listOf(180.dp, 145.dp, 115.dp, 95.dp)[abs(seed) % 4]
    val xOffsetDp = (((abs(seed) / 4) % 90) - 45).dp  // -45dp ~ +45dp

    // 浮遊アニメ（位置と微スケール）
    val transition = rememberInfiniteTransition(label = "bubble-$photoId")
    val phaseSec = 5 + (abs(seed) % 4)  // 5〜8 秒
    val translateY by transition.animateFloatAsState(
        initialValue = 0f, targetValue = -10f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = phaseSec * 1000),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "translateY"
    )
    val scaleAnim by transition.animateFloatAsState(
        initialValue = 1f, targetValue = 1.04f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = phaseSec * 1000),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "scaleAnim"
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
                            Color(0x1FFF78C8), Color(0x19_64C8FF),
                            Color(0x14_B4FFA0), Color(0x12_FFC864),
                            Color(0x19_C878FF),
                        )
                    )
                )
        )

        // 縁の光（リング）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .border(
                    width = 1.dp,
                    color = if (theme.isDark) Color(0x33FFFFFF) else Color(0x80FFFFFF),
                    shape = CircleShape,
                )
        )

        // ハイライト（左上）
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(Color(0x59FFFFFF), Color(0x00FFFFFF)),
                        center = androidx.compose.ui.geometry.Offset(x = sizeDp.value * 0.32f, y = sizeDp.value * 0.22f),
                        radius = sizeDp.value * 0.4f,
                    )
                )
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
    val labelColor = if (isDark) Color(0x70_9BAFEB) else Color(0x70_5060A0)
    val timeColor  = if (isDark) Color(0x47_82A5E6) else Color(0x4D_5060A0)
    val hours = remaining.inWholeHours
    val timeText = if (hours <= 0) "まもなく" else "あと ${hours}h"
    androidx.compose.foundation.layout.Column(
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = "現像中", fontSize = 9.sp, color = labelColor)
        Text(text = timeText, fontSize = 13.sp, color = timeColor)
    }
}
```

> **注**: 上記の `padding` import が抜けないように注意。`androidx.compose.foundation.layout.padding` が必要。エラーが出たら追加。

- [ ] **Step 2: import 漏れがあれば追加**

`androidx.compose.foundation.layout.padding` を import に追加（IDE が自動で入れる）。

- [ ] **Step 3: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/component/BubbleGalleryItem.kt
git commit -m "feat(sprint2): add BubbleGalleryItem with floating animation and iridescent film"
```

---

## Task 12: HomeScreen に BottomActionBar を配置

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt`

- [ ] **Step 1: HomeScreen のシグネチャと内容を更新**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt` を以下に置き換え:

```kotlin
package io.awairo.presentation.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
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
            contentAlignment = Alignment.Center
        ) {
            if (isTodayPhotoTaken) {
                GrayedOutBubble()
            } else if (cameraController.hasPermission()) {
                BubbleCameraView(
                    controller = cameraController,
                    onCaptured = { path ->
                        viewModel.refreshTodayStatus()
                        onPhotoCaptured(path)
                    }
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
```

- [ ] **Step 2: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`（新規パラメータは default あり、既存 `App.kt` の呼び出しは変更不要）

- [ ] **Step 3: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt
git commit -m "feat(sprint2): add BottomActionBar to HomeScreen with gallery + menu actions"
```

---

## Task 13: GalleryScreen + GalleryViewModel

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/GalleryViewModel.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/GalleryScreen.kt`

- [ ] **Step 1: GalleryViewModel を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/GalleryViewModel.kt`:

```kotlin
package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.DevelopedPhoto
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class GalleryViewModel(
    private val developPhoto: DevelopPhotoUseCase
) : ViewModel() {

    private val _photos = MutableStateFlow<List<DevelopedPhoto>>(emptyList())
    val photos: StateFlow<List<DevelopedPhoto>> = _photos.asStateFlow()

    init {
        viewModelScope.launch {
            while (true) {
                _photos.value = developPhoto()
                // 1分ごとに再評価して未現像 → 現像済みの自動切替を実現
                delay(60_000L)
            }
        }
    }

    fun refresh() {
        viewModelScope.launch { _photos.value = developPhoto() }
    }
}
```

- [ ] **Step 2: GalleryScreen を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/GalleryScreen.kt`:

```kotlin
package io.awairo.presentation.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
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
                Text(
                    text = "まだ泡がありません",
                    color = theme.textSecondary,
                    fontSize = 14.sp,
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(top = 24.dp, bottom = 80.dp),
            ) {
                item {
                    Text(
                        text = "AWA IRO",
                        color = theme.textSecondary,
                        fontSize = 11.sp,
                        modifier = Modifier.fillMaxSize().padding(bottom = 16.dp),
                    )
                }
                items(items = photos, key = { it.id }) { devPhoto ->
                    Box(
                        modifier = Modifier.fillMaxSize().padding(vertical = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        BubbleGalleryItem(
                            photoId = devPhoto.id,
                            imagePath = devPhoto.photo.imagePath,
                            dateLabel = formatDate(devPhoto),
                            isDeveloped = devPhoto.isDeveloped,
                            remaining = devPhoto.remaining,
                            indexInList = photos.indexOf(devPhoto),
                            onTap = {
                                if (devPhoto.isDeveloped) onPhotoTap(devPhoto.id)
                                // 未現像はタップしても何もしない（軽い揺れは将来追加）
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
```

- [ ] **Step 3: AppModule.kt に GalleryViewModel を追加登録**

`composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt` の `viewModel { ThemeViewModel(get()) }` の直後に追加:

```kotlin
    viewModel { GalleryViewModel(get()) }
```

import も追加:

```kotlin
import io.awairo.presentation.viewmodel.GalleryViewModel
```

- [ ] **Step 4: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/GalleryViewModel.kt \
        composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/GalleryScreen.kt \
        composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt
git commit -m "feat(sprint2): add GalleryScreen with bubble grid and 1-min auto refresh"
```

---

## Task 14: PhotoDetailScreen + PhotoDetailViewModel

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/PhotoDetailViewModel.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/PhotoDetailScreen.kt`

- [ ] **Step 1: PhotoDetailViewModel を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/PhotoDetailViewModel.kt`:

```kotlin
package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.DevelopedPhoto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 詳細画面用 ViewModel。現像済み写真のリストとその index を管理し、
 * メモ編集も提供する。
 */
class PhotoDetailViewModel(
    private val developPhoto: DevelopPhotoUseCase,
    private val repository: PhotoRepository,
) : ViewModel() {

    private val _developedPhotos = MutableStateFlow<List<DevelopedPhoto>>(emptyList())
    val developedPhotos: StateFlow<List<DevelopedPhoto>> = _developedPhotos.asStateFlow()

    /**
     * @return 指定 photoId の初期 index。見つからなければ 0。
     */
    suspend fun loadDevelopedAndFindIndex(photoId: String): Int {
        val all = developPhoto().filter { it.isDeveloped }
        _developedPhotos.value = all
        val idx = all.indexOfFirst { it.id == photoId }
        return if (idx >= 0) idx else 0
    }

    fun updateMemo(photoId: String, newMemo: String) {
        viewModelScope.launch {
            repository.updateMemo(photoId, newMemo)
            // メモ反映のためリストを更新
            _developedPhotos.value = developPhoto().filter { it.isDeveloped }
        }
    }
}
```

- [ ] **Step 2: PhotoDetailScreen を作成**

`composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/PhotoDetailScreen.kt`:

```kotlin
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
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.ImageLoader
import coil3.compose.AsyncImage
import coil3.compose.LocalPlatformContext
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.viewmodel.PhotoDetailViewModel
import kotlinx.coroutines.launch
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun PhotoDetailScreen(
    initialPhotoId: String,
    onBack: () -> Unit,
    onShareClick: () -> Unit,           // Sprint 3 で実装。今は何もしない or トースト
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
        Box(modifier = Modifier.fillMaxSize().background(theme.backgroundBottom),
            contentAlignment = Alignment.Center) {
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
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(onClick = onBack) {
                Text("← 戻る", color = theme.textPrimary)
            }
            TextButton(onClick = onShareClick) {
                Text("⤴ シェア", color = theme.textSecondary) // Sprint 3 で実装
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
    val ctx = LocalPlatformContext.current
    val loader = remember(ctx) { ImageLoader(ctx) }
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
                    modifier = Modifier.fillMaxWidth().clickable { editing = true },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = if (memo.isBlank()) "メモなし" else memo,
                        color = if (memo.isBlank()) theme.textSecondary else theme.textPrimary,
                        modifier = Modifier.weight(1f),
                        fontSize = 14.sp,
                    )
                    Text(
                        text = "✎",
                        color = theme.textSecondary,
                        fontSize = 16.sp,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }
        }
    }
}

private fun formatDateTime(instant: kotlinx.datetime.Instant): String {
    val tz = TimeZone.currentSystemDefault()
    val dt = instant.toLocalDateTime(tz)
    val mm = dt.monthNumber.toString().padStart(2, '0')
    val dd = dt.dayOfMonth.toString().padStart(2, '0')
    val hh = dt.hour.toString().padStart(2, '0')
    val mi = dt.minute.toString().padStart(2, '0')
    return "${dt.year} / $mm / $dd  $hh:$mi"
}
```

- [ ] **Step 3: AppModule.kt に PhotoDetailViewModel を追加登録**

`composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt` の `viewModel { GalleryViewModel(get()) }` の直後に追加:

```kotlin
    viewModel { PhotoDetailViewModel(get(), get()) }
```

import も追加:

```kotlin
import io.awairo.presentation.viewmodel.PhotoDetailViewModel
```

- [ ] **Step 4: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/presentation/viewmodel/PhotoDetailViewModel.kt \
        composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/PhotoDetailScreen.kt \
        composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt
git commit -m "feat(sprint2): add PhotoDetailScreen with HorizontalPager and inline memo edit"
```

---

## Task 15: App.kt にナビゲーションとテーマ Provider を組み込む

**Files:**
- Modify: `composeApp/src/commonMain/kotlin/io/awairo/App.kt`

- [ ] **Step 1: App.kt を全面置き換え**

`composeApp/src/commonMain/kotlin/io/awairo/App.kt`:

```kotlin
package io.awairo

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import io.awairo.presentation.component.PaletteSheet
import io.awairo.presentation.screen.GalleryScreen
import io.awairo.presentation.screen.HomeScreen
import io.awairo.presentation.screen.MemoScreen
import io.awairo.presentation.screen.PhotoDetailScreen
import io.awairo.presentation.theme.LocalSkyTheme
import io.awairo.presentation.theme.resolveSkyTheme
import io.awairo.presentation.viewmodel.ThemeViewModel
import org.koin.compose.viewmodel.koinViewModel

sealed class Screen {
    object Home : Screen()
    data class Memo(val absoluteImagePath: String) : Screen()
    object Gallery : Screen()
    data class PhotoDetail(val photoId: String) : Screen()
}

@Composable
fun App() {
    val themeVm: ThemeViewModel = koinViewModel()
    val mode by themeVm.themeMode.collectAsState()
    val palette by themeVm.skyPalette.collectAsState()
    val systemDark = isSystemInDarkTheme()
    val skyTheme = remember(mode, palette, systemDark) {
        resolveSkyTheme(palette, mode, systemDark)
    }

    var currentScreen: Screen by remember { mutableStateOf(Screen.Home) }
    var paletteOpen by remember { mutableStateOf(false) }

    CompositionLocalProvider(LocalSkyTheme provides skyTheme) {
        MaterialTheme {
            Surface(modifier = Modifier.fillMaxSize()) {
                Box(modifier = Modifier.fillMaxSize()) {
                    AnimatedContent(
                        targetState = currentScreen,
                        transitionSpec = {
                            (fadeIn() + scaleIn(initialScale = 0.96f))
                                .togetherWith(fadeOut() + scaleOut(targetScale = 1.04f))
                        },
                        label = "screen",
                    ) { screen ->
                        when (screen) {
                            is Screen.Home -> HomeScreen(
                                onPhotoCaptured = { absolutePath -> currentScreen = Screen.Memo(absolutePath) },
                                onOpenGallery = { currentScreen = Screen.Gallery },
                                onOpenMenu = { paletteOpen = !paletteOpen },
                            )
                            is Screen.Memo -> MemoScreen(
                                absoluteImagePath = screen.absoluteImagePath,
                                onSaved = { currentScreen = Screen.Home },
                                onCancel = { currentScreen = Screen.Home },
                            )
                            is Screen.Gallery -> GalleryScreen(
                                onPhotoTap = { id -> currentScreen = Screen.PhotoDetail(id) },
                                onBackToHome = { currentScreen = Screen.Home },
                                onOpenMenu = { paletteOpen = !paletteOpen },
                            )
                            is Screen.PhotoDetail -> PhotoDetailScreen(
                                initialPhotoId = screen.photoId,
                                onBack = { currentScreen = Screen.Gallery },
                                onShareClick = { /* Sprint 3 で実装 */ },
                            )
                        }
                    }

                    // パレットシートは最前面に
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        PaletteSheet(
                            visible = paletteOpen,
                            currentPalette = palette,
                            currentMode = mode,
                            onPaletteClick = { themeVm.setSkyPalette(it) },
                            onModeClick = { themeVm.setThemeMode(it) },
                        )
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: ビルド確認**

```bash
./gradlew :composeApp:assembleDebug
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: iOS フレームワークもビルド確認**

```bash
./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: 全テスト実行**

```bash
./gradlew :composeApp:testDebugUnitTest
```

Expected: 全テスト pass（PhotoTest 5件 + DevelopPhotoUseCaseTest 2件 ＝ 計 7 件 minimum）

- [ ] **Step 5: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/App.kt
git commit -m "feat(sprint2): wire navigation, AnimatedContent transitions and SkyTheme provider in App"
```

---

## Task 16: Android で実機/シミュレータ動作確認

**Files:** なし（マニュアル動作確認）

- [ ] **Step 1: Android デバッグビルドをインストール**

```bash
./gradlew :composeApp:installDebug
```

事前に Android Studio のシミュレータ起動 or 実機接続が必要。

- [ ] **Step 2: 以下の動作確認をマニュアルで実施**

- [ ] アプリ起動 → HomeScreen が表示される
- [ ] HomeScreen 下部に「泡たち」「メニュー」ボタンが見える
- [ ] 「メニュー」タップ → パレットシートがスライドアップ
- [ ] パレット切替 → 背景が変わる
- [ ] 「ダーク」「ライト」「システム」切替 → 背景が変わる
- [ ] アプリ再起動 → 選択したパレット・モードが保持されている
- [ ] 「泡たち」タップ → GalleryScreen に遷移
- [ ] 撮影直後の写真があれば未現像泡として表示される
- [ ] 24時間以上前の写真があれば現像済み泡として表示される
- [ ] 現像済み泡タップ → PhotoDetailScreen に遷移
- [ ] PhotoDetailScreen で写真とメモが表示される
- [ ] 左右スワイプで前後の現像済み写真に移動できる
- [ ] 「✎」アイコンタップ → メモ編集モード
- [ ] メモ編集 → 保存 → 戻ってもう一度開いて反映確認
- [ ] 「← 戻る」 → GalleryScreen
- [ ] 「⤴ シェア」 → 何もしない（Sprint 3 で実装予定）
- [ ] GalleryScreen の「ホーム」 → HomeScreen に戻る

問題があれば該当 Task に戻って修正。

---

## Task 17: iOS シミュレータで動作確認

**Files:** なし（マニュアル動作確認）

- [ ] **Step 1: iOS シミュレータで起動**

```bash
# Xcode で iosApp プロジェクトを開く
open iosApp/iosApp.xcodeproj

# Xcode 上でシミュレータターゲット選択 → Run（Cmd+R）
```

- [ ] **Step 2: Task 16 と同じチェックリストを iOS でも実施**

特に注意：
- [ ] HorizontalPager のスワイプが iOS でも自然に動くこと
- [ ] PaletteSheet のスライドアニメーションが滑らかであること
- [ ] パレット切替が NSUserDefaults 経由で永続化されていること（再起動して確認）

iOS 固有の問題があれば PlistSanityCheck の調整など `iosApp.xcodeproj/project.pbxproj` の追加修正も検討。

---

## Task 18: マニュアルチェックリスト追加

**Files:**
- Create: `docs/manual/sprint-2-verification.md`

- [ ] **Step 1: チェックリストを作成**

`docs/manual/sprint-2-verification.md`:

```markdown
# Sprint 2 — Develop マニュアル動作確認チェックリスト

実装完了後、Android / iOS の双方で以下を確認する。

## 基本ナビゲーション
- [ ] HomeScreen 起動
- [ ] 「泡たち」ボタン → GalleryScreen
- [ ] 「ホーム」ボタン → HomeScreen に戻る

## ギャラリー表示
- [ ] 写真が無いとき「まだ泡がありません」と表示
- [ ] 撮影直後の写真は未現像泡として表示（透明＋「あと○h」）
- [ ] 24時間経過後の写真は現像済み泡（写真が中に見える）
- [ ] 泡が縦スクロールで並ぶ
- [ ] 泡がそれぞれふわふわ揺れる
- [ ] 最新が一番上、古いものが下

## 詳細画面
- [ ] 現像済み泡タップ → PhotoDetailScreen 遷移
- [ ] 未現像泡タップ → 反応なし（Sprint 4+ で揺れアニメ）
- [ ] 写真がフルスクリーン近くで表示される
- [ ] メモが表示される（空欄は「メモなし」）
- [ ] ✎ アイコンでメモ編集モード
- [ ] 保存 → 戻ると反映済み
- [ ] 100文字制限が効く
- [ ] 左右スワイプで前後の現像済み写真に移動
- [ ] 「← 戻る」で GalleryScreen に戻る
- [ ] 「⤴ シェア」は無反応（Sprint 3 実装予定）

## テーマ
- [ ] 「メニュー」タップでパレットシートがスライドアップ
- [ ] 6つのパレット（夜空 / 霧海 / 夕暮れ / 木漏れ日 / 暁 / 銀霧）が選べる
- [ ] パレット選択で背景が変わる
- [ ] 「システム」「ダーク」「ライト」モードが切替できる
- [ ] アプリ再起動後も選択が保持されている
- [ ] OS のダークモード切替時、ThemeMode=SYSTEM なら自動追従

## 24時間経過の確認
- [ ] アプリで撮影 → ギャラリーで未現像確認
- [ ] 端末日時を24時間進める
- [ ] アプリ再起動 → 現像済みに切り替わる
- [ ] アプリ起動中（最大1分以内）に時刻が境界をまたいだら自動で現像済みに切り替わる

## 既知の制限事項
- 泡の border-radius モーフィング（CSS のような有機変形）は Sprint 4+ で実装予定
- 泡割れアニメーションの強化（パーティクル）は Sprint 4+ で実装予定
- 泡の個別色変更は Sprint 4+ で実装予定
- シェア機能は Sprint 3 で実装予定
```

- [ ] **Step 2: コミット**

```bash
git add docs/manual/sprint-2-verification.md
git commit -m "docs(sprint2): add manual verification checklist"
```

---

## Task 19: PR 作成

**Files:** なし

- [ ] **Step 1: ブランチをリモートに push**

```bash
git push -u origin feature/sprint2-develop
```

- [ ] **Step 2: PR 作成**

```bash
gh pr create \
  --title "Sprint 2: Develop（現像する）— bubble gallery + theme system" \
  --body "$(cat <<'EOF'
## Summary
- Bubble gallery (`GalleryScreen`) showing photos as floating soap-bubbles, latest at top
- 24h development logic via `DevelopPhotoUseCase` with injected `kotlinx.datetime.Clock` (testable)
- `PhotoDetailScreen` with `HorizontalPager` for prev/next navigation, inline memo editing
- Theme system: 6 named sky palettes (夜空 / 霧海 / 夕暮れ / 木漏れ日 / 暁 / 銀霧) with system / dark / light mode, persisted via `multiplatform-settings`
- Sprint 3 share button placeholder positioned in `PhotoDetailScreen`

## Spec
docs/superpowers/specs/2026-05-02-sprint-2-develop-design.md

## Plan
docs/superpowers/plans/2026-05-02-sprint-2-develop.md

## Test plan
- [x] commonTest: PhotoTest (5 tests), DevelopPhotoUseCaseTest (2 tests) all pass
- [x] Android emulator: full manual checklist (docs/manual/sprint-2-verification.md)
- [x] iOS simulator: full manual checklist
- [x] CI green

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: PR URL を確認し、CI 結果待ち**

CI が green になり、レビュー後に main にマージ → タグ `v0.3.0-sprint2` を付与（マージ後の作業）。

---

## 完了基準（このプランの成功条件）

- [ ] Task 1〜19 のすべてのチェックボックスが完了
- [ ] `./gradlew :composeApp:assembleDebug` 成功
- [ ] `./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64` 成功
- [ ] `./gradlew :composeApp:testDebugUnitTest` 全 pass（最低 7 件）
- [ ] Android / iOS のシミュレータでマニュアルチェックリスト全 pass
- [ ] PR の CI が green
- [ ] 設計書の「完了条件」セクション 18 項目すべて満たされる

---

## 既知のリスクと回避策

| リスク | 影響 | 回避策 |
|--------|------|--------|
| `multiplatform-settings 1.2.0` が Kotlin 2.2.x と非互換 | ビルド失敗 | `1.3.0` 以上に上げる（Task 1 で言及済み） |
| `HorizontalPager` の iOS でスワイプ反応鈍い | UX 劣化 | Compose 1.7.0 で動作実績あり、まずビルドして確認、ダメなら `pageSpacing` 調整 |
| 泡のアニメーションが iOS で 60fps 出ない | カクつき | `LazyColumn` で off-screen は描画されないので影響限定的、限界なら `phaseSec` を伸ばして CPU 負荷軽減 |
| Kotlin/AGP のローカル未コミット upgrade との衝突 | ビルド不可 | worktree は main の最新（コミット済み状態）からブランチを切るので影響なし |
| 1分間隔の自動現像チェックが過剰 | バッテリー | StateFlow は subscriber がいないと収集されないので画面非表示時は実質無効、必要なら `DisposableEffect` で停止 |

---

## 引き継ぎメモ（翌日以降の再開用）

このプランは完全に self-contained なので、翌日（または別セッション）でそのまま再開できる。

**再開手順:**

1. 本プラン (`docs/superpowers/plans/2026-05-02-sprint-2-develop.md`) を開く
2. 設計書 (`docs/superpowers/specs/2026-05-02-sprint-2-develop-design.md`) も開く
3. ベースライン確認の手順で worktree 作成（または既に作成済みなら `cd .worktrees/sprint2-develop`）
4. 完了済みの Task はチェックを付け、次の未チェック Task から再開
5. 各 Task の Step は 2〜5分単位で完結するので、空き時間で 1 Step ずつでも進められる

**Subagent 駆動で実装する場合:**

`superpowers:subagent-driven-development` skill を起動すると、各 Task ごとに：
1. implementer subagent が TDD で実装
2. spec reviewer subagent が設計書との整合確認
3. code quality reviewer subagent が品質確認
を自動で回してくれる。

**インライン実装する場合:**

`superpowers:executing-plans` skill を使うと、Task をバッチで実行しチェックポイントごとにレビューする。

どちらの方式でも、本プランの Task 単位で進めれば実装中の判断ミスは最小化される。
