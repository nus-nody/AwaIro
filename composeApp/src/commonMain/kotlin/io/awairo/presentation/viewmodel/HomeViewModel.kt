package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.repository.PhotoRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime

class HomeViewModel(private val repository: PhotoRepository) : ViewModel() {

    private val _isTodayPhotoTaken = MutableStateFlow(false)
    val isTodayPhotoTaken: StateFlow<Boolean> = _isTodayPhotoTaken

    init {
        refreshTodayStatus()
    }

    fun refreshTodayStatus() {
        viewModelScope.launch {
            val today = Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()).date
            val photos = repository.findByLocalDate(today)
            _isTodayPhotoTaken.value = photos.isNotEmpty()
        }
    }
}
