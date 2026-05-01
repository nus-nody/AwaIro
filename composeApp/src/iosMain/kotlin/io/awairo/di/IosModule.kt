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
