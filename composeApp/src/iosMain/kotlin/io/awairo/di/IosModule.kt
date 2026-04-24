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
