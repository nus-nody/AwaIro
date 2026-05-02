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
