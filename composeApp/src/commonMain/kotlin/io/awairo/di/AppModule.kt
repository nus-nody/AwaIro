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
