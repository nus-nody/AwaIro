package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.usecase.RecordPhotoUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class MemoViewModel(private val recordPhotoUseCase: RecordPhotoUseCase) : ViewModel() {

    sealed class SaveState {
        object Idle : SaveState()
        object Saving : SaveState()
        object Success : SaveState()
        data class Error(val message: String) : SaveState()
    }

    private val _saveState = MutableStateFlow<SaveState>(SaveState.Idle)
    val saveState: StateFlow<SaveState> = _saveState

    fun save(absoluteImagePath: String, memo: String) {
        viewModelScope.launch {
            _saveState.value = SaveState.Saving
            val result = recordPhotoUseCase.execute(absoluteImagePath, memo)
            _saveState.value = when (result) {
                is RecordPhotoUseCase.Result.Success -> SaveState.Success
                is RecordPhotoUseCase.Result.AlreadyTakenToday ->
                    SaveState.Error("今日はすでに1枚撮影済みです")
                is RecordPhotoUseCase.Result.Error ->
                    SaveState.Error("保存に失敗しました: ${result.cause.message}")
            }
        }
    }

    fun resetState() {
        _saveState.value = SaveState.Idle
    }
}
