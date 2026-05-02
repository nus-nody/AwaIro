package io.awairo.di

import coil3.PlatformContext
import com.russhwolf.settings.Settings
import com.russhwolf.settings.SharedPreferencesSettings
import io.awairo.data.local.DatabaseFactory
import io.awairo.platform.camera.CameraController
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

fun androidModule() = module {
    single { DatabaseFactory(androidContext()) }
    single<PlatformContext> { androidContext() }
    // Sprint 1
    single { CameraController(androidContext()) }
    // Sprint 2
    single<Settings> {
        val prefs = androidContext().getSharedPreferences("awa_iro_prefs", android.content.Context.MODE_PRIVATE)
        SharedPreferencesSettings(prefs)
    }
}
