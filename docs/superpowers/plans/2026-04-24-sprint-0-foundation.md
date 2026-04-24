# Sprint 0: 基盤構築 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compose Multiplatform（iOS/Android）のプロジェクト基盤を作り、Clean Architectureの骨格、ローカルDB、DI、CIを整備し、Sprint 1以降の機能追加が差し込めるだけの状態にする。

**Architecture:** Clean Architecture 3層（Presentation/Domain/Data）。ローカル完結、通信機能なし。各スプリントでUseCase追加のみで機能が増える設計。

**Tech Stack:** Kotlin Multiplatform, Compose Multiplatform, SQLDelight, Koin, kotlinx-datetime, Gradle Version Catalog, GitHub Actions

---

## 前提条件（Enablerタスク — ユーザー側で事前実施）

実装を始める前に、以下のインストールと設定を完了してください。完了順の目安付きです。

- [ ] **E1:** JDK 17 をインストール（`brew install openjdk@17` → `java -version` で17以上確認）
- [ ] **E2:** Android Studio をインストール（https://developer.android.com/studio）
- [ ] **E3:** Android Studio 起動時に **Kotlin Multiplatform plugin** をインストール
- [ ] **E4:** Android SDK (API 34) をAndroid Studio SDK Managerから取得
- [ ] **E5:** Xcode をMac App Storeからインストール（容量大・時間長）
- [ ] **E6:** `xcode-select --install` でCLIツール追加
- [ ] **E7:** `brew install gh` で GitHub CLI インストール
- [ ] **E8:** `gh auth login` でGitHub認証
- [ ] **E9:** `brew install node` でNode.js（補助ツール用）
- [ ] **E10:** GitHubで `AwaIro` リポジトリを作成（パブリック推奨：CI無料枠が無制限）
- [ ] **E11:** `git remote add origin <URL>` でローカルをGitHubに紐付け

---

## ファイル構成マップ

このSprintで作成する主要ファイル：

```
AwaIro/
├── .gitignore
├── README.md
├── settings.gradle.kts           # ルート設定
├── build.gradle.kts              # ルートビルド
├── gradle.properties             # Kotlin/KMP設定
├── gradle/
│   ├── libs.versions.toml        # Version Catalog (依存関係一元管理)
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew                       # Gradle wrapper
├── gradlew.bat
├── composeApp/
│   ├── build.gradle.kts
│   └── src/
│       ├── commonMain/
│       │   ├── kotlin/io/awairo/
│       │   │   ├── App.kt                                  # Compose Root
│       │   │   ├── di/AppModule.kt                         # Koin module
│       │   │   ├── domain/
│       │   │   │   ├── model/Photo.kt
│       │   │   │   └── repository/PhotoRepository.kt
│       │   │   ├── data/
│       │   │   │   ├── local/DatabaseFactory.kt            # expect
│       │   │   │   └── repository/LocalPhotoRepository.kt
│       │   │   ├── presentation/
│       │   │   │   ├── screen/HomeScreen.kt                # Hello World画面
│       │   │   │   └── viewmodel/HomeViewModel.kt
│       │   │   ├── platform/
│       │   │   │   ├── FirstLaunchGate.kt                  # expect (チュートリアル拡張点)
│       │   │   │   └── ShareService.kt                     # expect (シェア拡張点)
│       │   └── sqldelight/io/awairo/db/Photo.sq            # SQLDelightスキーマ
│       ├── androidMain/kotlin/io/awairo/
│       │   ├── MainActivity.kt
│       │   ├── Platform.android.kt
│       │   ├── data/local/DatabaseFactory.android.kt       # actual
│       │   └── platform/
│       │       ├── FirstLaunchGate.android.kt              # actual (空実装)
│       │       └── ShareService.android.kt                 # actual (空実装)
│       └── iosMain/kotlin/io/awairo/
│           ├── MainViewController.kt
│           ├── Platform.ios.kt
│           ├── data/local/DatabaseFactory.ios.kt           # actual
│           └── platform/
│               ├── FirstLaunchGate.ios.kt                  # actual (空実装)
│               └── ShareService.ios.kt                     # actual (空実装)
├── iosApp/
│   ├── iosApp.xcodeproj/
│   └── iosApp/
│       ├── iOSApp.swift
│       └── ContentView.swift
└── .github/
    └── workflows/
        └── ci.yml
```

---

## Task 1: プロジェクト初期化（ベース生成）

**Files:**
- Create: プロジェクト全体（Gradle wrapper含む）
- Create: `.gitignore`

- [ ] **Step 1.1: Kotlin Multiplatform Wizardで雛形生成**

Compose Multiplatformプロジェクトの雛形は、手書きするよりJetBrains公式ウィザードの出力を使う方が確実。

**オプションA（推奨）: ウィザード利用**
- https://kmp.jetbrains.com/ にアクセス
- プロジェクト名: `AwaIro`、Package: `io.awairo`
- ターゲット: Android + iOS、Shareable UI: Compose Multiplatform
- ダウンロードしたZipを `/Users/nodayouta/Documents/code/AwaIro/` に展開（既存ディレクトリにマージ）

**オプションB: Claude Codeが直接生成（Node.jsインストール後に `gradle init` を使用）**

- [ ] **Step 1.2: .gitignoreを作成**

```gitignore
# Gradle
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar
!gradle-wrapper.properties

# IDE
.idea/
*.iml
.vscode/
local.properties

# Kotlin
.kotlin/

# iOS
iosApp/Pods/
iosApp/iosApp.xcodeproj/xcuserdata/
iosApp/iosApp.xcodeproj/project.xcworkspace/xcuserdata/
*.xcworkspace/xcuserdata
xcuserdata/
*.xcuserstate
DerivedData/

# Node
node_modules/

# OS
.DS_Store
Thumbs.db

# Superpowers
.superpowers/
```

- [ ] **Step 1.3: READMEを作成**

```markdown
# AwaIro

1日1枚だけ、翌日まで見られない。感情の痕跡を溜めるフォトウォークアプリ。

## 開発セットアップ
詳細は [docs/manual/00-prerequisites.md](docs/manual/00-prerequisites.md) を参照。

## ビルド
- Android: `./gradlew :composeApp:assembleDebug`
- iOS: Xcodeで `iosApp/iosApp.xcodeproj` を開いてビルド
```

- [ ] **Step 1.4: 初回ビルド確認**

Run: `./gradlew :composeApp:assembleDebug`
Expected: BUILD SUCCESSFUL（Hello World雛形のAPKが生成される）

- [ ] **Step 1.5: コミット**

```bash
git add -A
git commit -m "chore: initialize Compose Multiplatform project from wizard"
```

---

## Task 2: Version Catalog整備

**Files:**
- Modify: `gradle/libs.versions.toml`

- [ ] **Step 2.1: 依存関係を `libs.versions.toml` に集約**

```toml
[versions]
kotlin = "2.0.21"
compose-multiplatform = "1.7.0"
agp = "8.7.2"
android-compile-sdk = "35"
android-target-sdk = "35"
android-min-sdk = "34"
androidx-activity-compose = "1.9.3"
androidx-lifecycle = "2.8.4"
koin = "4.0.0"
kotlinx-coroutines = "1.9.0"
kotlinx-datetime = "0.6.1"
sqldelight = "2.0.2"

[libraries]
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "androidx-activity-compose" }
androidx-lifecycle-viewmodel = { module = "androidx.lifecycle:lifecycle-viewmodel", version.ref = "androidx-lifecycle" }
koin-core = { module = "io.insert-koin:koin-core", version.ref = "koin" }
koin-compose = { module = "io.insert-koin:koin-compose", version.ref = "koin" }
koin-android = { module = "io.insert-koin:koin-android", version.ref = "koin" }
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "kotlinx-coroutines" }
kotlinx-datetime = { module = "org.jetbrains.kotlinx:kotlinx-datetime", version.ref = "kotlinx-datetime" }
sqldelight-runtime = { module = "app.cash.sqldelight:runtime", version.ref = "sqldelight" }
sqldelight-coroutines = { module = "app.cash.sqldelight:coroutines-extensions", version.ref = "sqldelight" }
sqldelight-android-driver = { module = "app.cash.sqldelight:android-driver", version.ref = "sqldelight" }
sqldelight-native-driver = { module = "app.cash.sqldelight:native-driver", version.ref = "sqldelight" }

[plugins]
kotlin-multiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
android-application = { id = "com.android.application", version.ref = "agp" }
compose-multiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
sqldelight = { id = "app.cash.sqldelight", version.ref = "sqldelight" }
```

- [ ] **Step 2.2: コミット**

```bash
git add gradle/libs.versions.toml
git commit -m "chore: define version catalog for dependencies"
```

---

## Task 3: composeApp/build.gradle.kts に依存追加

**Files:**
- Modify: `composeApp/build.gradle.kts`

- [ ] **Step 3.1: build.gradle.ktsを編集して依存を追加**

既存の雛形に以下を追加／置換：

```kotlin
plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.sqldelight)
}

kotlin {
    androidTarget()
    
    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "ComposeApp"
            isStatic = true
        }
    }

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
        }
        androidMain.dependencies {
            implementation(libs.androidx.activity.compose)
            implementation(libs.koin.android)
            implementation(libs.sqldelight.android.driver)
        }
        iosMain.dependencies {
            implementation(libs.sqldelight.native.driver)
        }
    }
}

android {
    namespace = "io.awairo"
    compileSdk = libs.versions.android.compile.sdk.get().toInt()
    defaultConfig {
        applicationId = "io.awairo"
        minSdk = libs.versions.android.min.sdk.get().toInt()
        targetSdk = libs.versions.android.target.sdk.get().toInt()
        versionCode = 1
        versionName = "0.1.0"
    }
    // バックアップ除外（設計方針どおり）
}

sqldelight {
    databases {
        create("AwaIroDatabase") {
            packageName.set("io.awairo.db")
        }
    }
}
```

- [ ] **Step 3.2: 依存解決のためにビルド実行**

Run: `./gradlew :composeApp:assembleDebug`
Expected: BUILD SUCCESSFUL（まだSQLDelightスキーマは無いのでWarningは出る可能性あり）

- [ ] **Step 3.3: コミット**

```bash
git add composeApp/build.gradle.kts
git commit -m "chore(composeApp): wire dependencies via version catalog"
```

---

## Task 4: SQLDelightスキーマ定義

**Files:**
- Create: `composeApp/src/commonMain/sqldelight/io/awairo/db/Photo.sq`

- [ ] **Step 4.1: スキーマファイルを作成**

```sql
CREATE TABLE Photo (
    id TEXT NOT NULL PRIMARY KEY,
    captured_at INTEGER NOT NULL,
    developed_at INTEGER NOT NULL,
    image_path TEXT NOT NULL,
    memo TEXT NOT NULL,
    area_label TEXT NOT NULL
);

CREATE INDEX photo_captured_at ON Photo(captured_at);

insertPhoto:
INSERT INTO Photo(id, captured_at, developed_at, image_path, memo, area_label)
VALUES (?, ?, ?, ?, ?, ?);

selectById:
SELECT * FROM Photo WHERE id = ?;

selectByDateRange:
SELECT * FROM Photo
WHERE captured_at >= ? AND captured_at < ?
ORDER BY captured_at ASC;

selectDeveloped:
SELECT * FROM Photo
WHERE developed_at <= ?
ORDER BY captured_at DESC;

countByDateRange:
SELECT COUNT(*) FROM Photo
WHERE captured_at >= ? AND captured_at < ?;

deleteById:
DELETE FROM Photo WHERE id = ?;
```

- [ ] **Step 4.2: SQLDelightコード生成を確認**

Run: `./gradlew :composeApp:generateCommonMainAwaIroDatabaseInterface`
Expected: BUILD SUCCESSFUL、`composeApp/build/generated/sqldelight/` 以下にKotlinコードが生成される

- [ ] **Step 4.3: コミット**

```bash
git add composeApp/src/commonMain/sqldelight/
git commit -m "feat(data): define Photo table schema"
```

---

## Task 5: Domain層の定義

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/model/Photo.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/domain/repository/PhotoRepository.kt`

- [ ] **Step 5.1: Photo モデルを作成**

```kotlin
package io.awairo.domain.model

import kotlinx.datetime.Instant

data class Photo(
    val id: String,
    val capturedAt: Instant,
    val developedAt: Instant,
    val imagePath: String,
    val memo: String,
    val areaLabel: String
) {
    fun isDeveloped(now: Instant): Boolean = now >= developedAt
}
```

- [ ] **Step 5.2: PhotoRepository インターフェースを作成**

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
}
```

- [ ] **Step 5.3: コンパイル確認**

Run: `./gradlew :composeApp:compileKotlinMetadata`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5.4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/domain/
git commit -m "feat(domain): define Photo model and repository interface"
```

---

## Task 6: Data層の実装

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/data/local/DatabaseFactory.kt` (expect)
- Create: `composeApp/src/androidMain/kotlin/io/awairo/data/local/DatabaseFactory.android.kt`
- Create: `composeApp/src/iosMain/kotlin/io/awairo/data/local/DatabaseFactory.ios.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/data/repository/LocalPhotoRepository.kt`

- [ ] **Step 6.1: expect DatabaseFactoryを作成**

```kotlin
package io.awairo.data.local

import app.cash.sqldelight.db.SqlDriver

expect class DatabaseFactory {
    fun createDriver(): SqlDriver
}
```

- [ ] **Step 6.2: Android実装**

```kotlin
package io.awairo.data.local

import android.content.Context
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import io.awairo.db.AwaIroDatabase

actual class DatabaseFactory(private val context: Context) {
    actual fun createDriver(): SqlDriver {
        return AndroidSqliteDriver(
            schema = AwaIroDatabase.Schema,
            context = context,
            name = "awairo.db"
        )
    }
}
```

- [ ] **Step 6.3: iOS実装**

```kotlin
package io.awairo.data.local

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import io.awairo.db.AwaIroDatabase

actual class DatabaseFactory {
    actual fun createDriver(): SqlDriver {
        return NativeSqliteDriver(
            schema = AwaIroDatabase.Schema,
            name = "awairo.db"
        )
    }
}
```

- [ ] **Step 6.4: LocalPhotoRepository実装**

```kotlin
package io.awairo.data.repository

import io.awairo.db.AwaIroDatabase
import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.DatePeriod

class LocalPhotoRepository(
    private val database: AwaIroDatabase
) : PhotoRepository {

    override suspend fun save(photo: Photo) {
        database.photoQueries.insertPhoto(
            id = photo.id,
            captured_at = photo.capturedAt.toEpochMilliseconds(),
            developed_at = photo.developedAt.toEpochMilliseconds(),
            image_path = photo.imagePath,
            memo = photo.memo,
            area_label = photo.areaLabel
        )
    }

    override suspend fun findById(id: String): Photo? =
        database.photoQueries.selectById(id).executeAsOneOrNull()?.toDomain()

    override suspend fun findByLocalDate(date: LocalDate): List<Photo> {
        val start = date.atStartOfDayIn(TimeZone.currentSystemDefault()).toEpochMilliseconds()
        val end = date.plus(DatePeriod(days = 1))
            .atStartOfDayIn(TimeZone.currentSystemDefault()).toEpochMilliseconds()
        return database.photoQueries.selectByDateRange(start, end)
            .executeAsList().map { it.toDomain() }
    }

    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> =
        database.photoQueries.selectDeveloped(now.toEpochMilliseconds())
            .executeAsList().map { it.toDomain() }

    override suspend fun delete(id: String) {
        database.photoQueries.deleteById(id)
    }

    private fun io.awairo.db.Photo.toDomain() = Photo(
        id = id,
        capturedAt = Instant.fromEpochMilliseconds(captured_at),
        developedAt = Instant.fromEpochMilliseconds(developed_at),
        imagePath = image_path,
        memo = memo,
        areaLabel = area_label
    )
}
```

- [ ] **Step 6.5: ビルド確認**

Run: `./gradlew :composeApp:compileDebugKotlinAndroid`
Expected: BUILD SUCCESSFUL

- [ ] **Step 6.6: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/data/ \
        composeApp/src/androidMain/kotlin/io/awairo/data/ \
        composeApp/src/iosMain/kotlin/io/awairo/data/
git commit -m "feat(data): implement LocalPhotoRepository with SQLDelight"
```

---

## Task 7: プラットフォーム拡張点（FirstLaunchGate / ShareService）

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/platform/FirstLaunchGate.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/platform/ShareService.kt`
- Create: `composeApp/src/androidMain/kotlin/io/awairo/platform/FirstLaunchGate.android.kt`
- Create: `composeApp/src/androidMain/kotlin/io/awairo/platform/ShareService.android.kt`
- Create: `composeApp/src/iosMain/kotlin/io/awairo/platform/FirstLaunchGate.ios.kt`
- Create: `composeApp/src/iosMain/kotlin/io/awairo/platform/ShareService.ios.kt`

- [ ] **Step 7.1: FirstLaunchGate インターフェース（common）**

```kotlin
package io.awairo.platform

interface FirstLaunchGate {
    fun shouldShowOnboarding(): Boolean
    fun markOnboardingCompleted()
}
```

- [ ] **Step 7.2: ShareService インターフェース（common）**

```kotlin
package io.awairo.platform

interface ShareService {
    suspend fun shareImage(imagePath: String, caption: String)
    suspend fun saveToGallery(imagePath: String)
}
```

- [ ] **Step 7.3: Android側 空実装**

FirstLaunchGate.android.kt:
```kotlin
package io.awairo.platform

class AndroidFirstLaunchGate : FirstLaunchGate {
    override fun shouldShowOnboarding(): Boolean = false
    override fun markOnboardingCompleted() {
        // Sprint 0では空実装。チュートリアル追加時に実装
    }
}
```

ShareService.android.kt:
```kotlin
package io.awairo.platform

class AndroidShareService : ShareService {
    override suspend fun shareImage(imagePath: String, caption: String) {
        // Sprint 3で Intent.ACTION_SEND を使って実装
        TODO("Implemented in Sprint 3")
    }

    override suspend fun saveToGallery(imagePath: String) {
        TODO("Implemented in Sprint 3")
    }
}
```

- [ ] **Step 7.4: iOS側 空実装**

FirstLaunchGate.ios.kt:
```kotlin
package io.awairo.platform

class IosFirstLaunchGate : FirstLaunchGate {
    override fun shouldShowOnboarding(): Boolean = false
    override fun markOnboardingCompleted() {
        // Sprint 0では空実装
    }
}
```

ShareService.ios.kt:
```kotlin
package io.awairo.platform

class IosShareService : ShareService {
    override suspend fun shareImage(imagePath: String, caption: String) {
        TODO("Implemented in Sprint 3")
    }

    override suspend fun saveToGallery(imagePath: String) {
        TODO("Implemented in Sprint 3")
    }
}
```

> 注: `TODO()` は未実装でもコンパイルは通る。呼び出すと実行時エラーになるが、Sprint 0では呼び出さないのでOK。

- [ ] **Step 7.5: ビルド確認**

Run: `./gradlew :composeApp:compileDebugKotlinAndroid`
Expected: BUILD SUCCESSFUL

- [ ] **Step 7.6: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/platform/ \
        composeApp/src/androidMain/kotlin/io/awairo/platform/ \
        composeApp/src/iosMain/kotlin/io/awairo/platform/
git commit -m "feat(platform): add FirstLaunchGate and ShareService extension points"
```

---

## Task 8: Koin DI 設定

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/di/AppModule.kt`

- [ ] **Step 8.1: AppModule を作成**

```kotlin
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import org.koin.dsl.module

fun appModule() = module {
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }
}
```

- [ ] **Step 8.2: Android側でDatabaseFactoryをKoinに登録するためのモジュール**

Create: `composeApp/src/androidMain/kotlin/io/awairo/di/AndroidModule.kt`

```kotlin
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

fun androidModule() = module {
    single { DatabaseFactory(androidContext()) }
}
```

- [ ] **Step 8.3: iOS側 Koin初期化用ヘルパー**

Create: `composeApp/src/iosMain/kotlin/io/awairo/di/IosModule.kt`

```kotlin
package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import org.koin.core.context.startKoin
import org.koin.dsl.module

fun iosModule() = module {
    single { DatabaseFactory() }
}

fun initKoinForIos() {
    startKoin {
        modules(iosModule(), appModule())
    }
}
```

- [ ] **Step 8.4: コミット**

```bash
git add composeApp/src/commonMain/kotlin/io/awairo/di/ \
        composeApp/src/androidMain/kotlin/io/awairo/di/ \
        composeApp/src/iosMain/kotlin/io/awairo/di/
git commit -m "feat(di): wire repositories and database via Koin"
```

---

## Task 9: Presentation層の骨格 + Hello World画面

**Files:**
- Create: `composeApp/src/commonMain/kotlin/io/awairo/App.kt`
- Create: `composeApp/src/commonMain/kotlin/io/awairo/presentation/screen/HomeScreen.kt`

- [ ] **Step 9.1: Hello Screen を作成**

```kotlin
package io.awairo.presentation.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

@Composable
fun HomeScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text("AwaIro - Sprint 0 Foundation OK")
    }
}
```

- [ ] **Step 9.2: App composable**

```kotlin
package io.awairo

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import io.awairo.presentation.screen.HomeScreen
import org.koin.compose.KoinApplication
import io.awairo.di.appModule

@Composable
fun App() {
    KoinApplication(application = { modules(appModule()) }) {
        MaterialTheme {
            Surface {
                HomeScreen()
            }
        }
    }
}
```

- [ ] **Step 9.3: MainActivity を更新（Android）**

`composeApp/src/androidMain/kotlin/io/awairo/MainActivity.kt`:
```kotlin
package io.awairo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}
```

AndroidManifest.xml もapplicationタグに `android:allowBackup="false"` を付けてバックアップ除外：

```xml
<application
    android:name=".AwaIroApplication"
    android:allowBackup="false"
    ...>
```

`AwaIroApplication.kt` を作成:
```kotlin
package io.awairo

import android.app.Application
import io.awairo.di.androidModule
import io.awairo.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin

class AwaIroApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@AwaIroApplication)
            modules(androidModule(), appModule())
        }
    }
}
```

- [ ] **Step 9.4: MainViewController を更新（iOS）**

`composeApp/src/iosMain/kotlin/io/awairo/MainViewController.kt`:
```kotlin
package io.awairo

import androidx.compose.ui.window.ComposeUIViewController
import io.awairo.di.initKoinForIos

fun MainViewController() = ComposeUIViewController(
    configure = { initKoinForIos() }
) {
    App()
}
```

- [ ] **Step 9.5: Android ビルド & シミュレータで動作確認**

Run: `./gradlew :composeApp:installDebug`
Expected: インストール成功 → 起動すると「AwaIro - Sprint 0 Foundation OK」が表示される

- [ ] **Step 9.6: iOS ビルド確認**

Xcodeで `iosApp/iosApp.xcodeproj` を開き、シミュレータで Run する。
Expected: 同じテキストが表示される

- [ ] **Step 9.7: コミット**

```bash
git add -A
git commit -m "feat(ui): add Hello World home screen with Koin wiring"
```

---

## Task 10: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 10.1: CI ワークフロー作成**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: gradle/actions/setup-gradle@v4
      - name: Build Android Debug
        run: ./gradlew :composeApp:assembleDebug

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: gradle/actions/setup-gradle@v4
      - name: Build iOS framework
        run: ./gradlew :composeApp:linkDebugFrameworkIosSimulatorArm64
```

- [ ] **Step 10.2: GitHubへプッシュしてCIを確認**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions for Android and iOS builds"
git push origin main
```

- [ ] **Step 10.3: CI結果を確認**

Run: `gh run list --limit 1`
Expected: status が `completed` かつ conclusion が `success`

もし失敗したら、`gh run view --log-failed` でログを見て修正してコミット。

---

## Task 11: Sprint 0 完了チェック

- [ ] **Step 11.1: 設計書の完了条件を再確認**

[docs/superpowers/specs/2026-04-24-awairo-design.md](../specs/2026-04-24-awairo-design.md) Section 6 Sprint 0 完了条件の全項目にチェック。

- [ ] **Step 11.2: 動作スクリーンショットを `docs/screenshots/sprint-0/` に保存**

Android / iOS両方で Hello World画面をスクショ。

- [ ] **Step 11.3: Sprint 0 完了タグを打つ**

```bash
git tag v0.1.0-sprint0
git push --tags
```

- [ ] **Step 11.4: Sprint 1 の計画をClaude Codeに依頼する**

「Sprint 1 の実装計画を作って」と依頼すれば、同じ形式で `docs/superpowers/plans/2026-XX-XX-sprint-1-record.md` が作られます。

---

## 付録: よくあるビルドエラーと対処

| エラー | 対処 |
|--------|------|
| `Cannot find org.jetbrains.compose` | `gradle.properties` に `kotlin.native.cacheKind=none` を追加 |
| iOS: `framework not found` | Xcodeで Product > Clean Build Folder 後に再ビルド |
| `Could not resolve SqlDelight` | Gradle Sync を実行 |
| Android `minSdk` エラー | `libs.versions.toml` の `android-min-sdk` を確認 |
