package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

fun androidModule() = module {
    single { DatabaseFactory(androidContext()) }
}
