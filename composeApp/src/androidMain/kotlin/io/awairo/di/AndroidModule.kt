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
