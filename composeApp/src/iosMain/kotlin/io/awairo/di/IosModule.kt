package io.awairo.di

import coil3.PlatformContext
import com.russhwolf.settings.NSUserDefaultsSettings
import com.russhwolf.settings.Settings
import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.core.context.startKoin
import org.koin.dsl.module
import platform.Foundation.NSUserDefaults

fun iosModule() = module {
    single { DatabaseFactory() }
    single<PlatformContext> { PlatformContext.INSTANCE }
    // Sprint 1
    single { CameraController() }
    // Sprint 2
    single<Settings> {
        NSUserDefaultsSettings(
            NSUserDefaults.standardUserDefaults
                ?: error("NSUserDefaults.standardUserDefaults is null")
        )
    }
}

fun initKoinForIos() {
    startKoin {
        modules(iosModule(), appModule())
    }
}
