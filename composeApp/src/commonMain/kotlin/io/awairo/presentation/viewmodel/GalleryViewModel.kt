package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.DevelopedPhoto
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class GalleryViewModel(
    private val developPhoto: DevelopPhotoUseCase,
) : ViewModel() {

    private val _photos = MutableStateFlow<List<DevelopedPhoto>>(emptyList())
    val photos: StateFlow<List<DevelopedPhoto>> = _photos.asStateFlow()

    init {
        viewModelScope.launch {
            while (true) {
                _photos.value = developPhoto()
                // 1分ごとに再評価して未現像 → 現像済みの自動切替を実現
                delay(60_000L)
            }
        }
    }

    fun refresh() {
        viewModelScope.launch { _photos.value = developPhoto() }
    }
}
