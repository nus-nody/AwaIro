package io.awairo.di

import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.data.repository.SettingsThemeRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.repository.ThemeRepository
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.RecordPhotoUseCase
import io.awairo.presentation.viewmodel.HomeViewModel
import io.awairo.presentation.viewmodel.MemoViewModel
import io.awairo.presentation.viewmodel.ThemeViewModel
import kotlinx.datetime.Clock
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

fun appModule() = module {
    single { AwaIroDatabase(get<DatabaseFactory>().createDriver()) }
    single<PhotoRepository> { LocalPhotoRepository(get()) }
    // Sprint 1
    factory { RecordPhotoUseCase(get()) }
    viewModel { HomeViewModel(get()) }
    viewModel { MemoViewModel(get()) }
    // Sprint 2
    single<Clock> { Clock.System }
    single<ThemeRepository> { SettingsThemeRepository(get()) }
    factory { DevelopPhotoUseCase(get(), get()) }
    viewModel { ThemeViewModel(get()) }
    // GalleryViewModel と PhotoDetailViewModel は Task 13 / Task 14 で追加する
}
