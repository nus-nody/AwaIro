package io.awairo.di

import coil3.ImageLoader
import coil3.PlatformContext
import io.awairo.data.local.DatabaseFactory
import io.awairo.data.repository.LocalPhotoRepository
import io.awairo.data.repository.SettingsThemeRepository
import io.awairo.db.AwaIroDatabase
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.repository.ThemeRepository
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.RecordPhotoUseCase
import io.awairo.presentation.viewmodel.GalleryViewModel
import io.awairo.presentation.viewmodel.HomeViewModel
import io.awairo.presentation.viewmodel.MemoViewModel
import io.awairo.presentation.viewmodel.PhotoDetailViewModel
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
    viewModel { GalleryViewModel(get()) }
    viewModel { PhotoDetailViewModel(get(), get()) }
    // Coil ImageLoader singleton — shared across all screens
    single<ImageLoader> { ImageLoader.Builder(get<PlatformContext>()).build() }
}
