package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.usecase.RecordPhotoUseCase
import io.awairo.presentation.viewmodel.HomeViewModel
import io.awairo.presentation.viewmodel.MemoViewModel
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

fun appModule() = module {
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }
    // Sprint 1 追加
    factory { RecordPhotoUseCase(get()) }
    viewModel { HomeViewModel(get()) }
    viewModel { MemoViewModel(get()) }
}
