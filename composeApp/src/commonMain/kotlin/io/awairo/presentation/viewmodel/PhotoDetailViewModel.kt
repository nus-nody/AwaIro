package io.awairo.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.awairo.domain.repository.PhotoRepository
import io.awairo.domain.usecase.DevelopPhotoUseCase
import io.awairo.domain.usecase.DevelopedPhoto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 詳細画面用 ViewModel。現像済み写真のリストとその index を管理し、
 * メモ編集も提供する。
 */
class PhotoDetailViewModel(
    private val developPhoto: DevelopPhotoUseCase,
    private val repository: PhotoRepository,
) : ViewModel() {

    private val _developedPhotos = MutableStateFlow<List<DevelopedPhoto>>(emptyList())
    val developedPhotos: StateFlow<List<DevelopedPhoto>> = _developedPhotos.asStateFlow()

    /**
     * @return 指定 photoId の初期 index。見つからなければ 0。
     */
    suspend fun loadDevelopedAndFindIndex(photoId: String): Int {
        val all = developPhoto().filter { it.isDeveloped }
        _developedPhotos.value = all
        val idx = all.indexOfFirst { it.id == photoId }
        return if (idx >= 0) idx else 0
    }

    fun updateMemo(photoId: String, newMemo: String) {
        // 楽観的更新: DB 書き込みより前に in-memory state を更新して、UI を即時反映する
        val currentList = _developedPhotos.value
        val idx = currentList.indexOfFirst { it.id == photoId }
        if (idx >= 0) {
            val current = currentList[idx]
            val updated = current.copy(photo = current.photo.copy(memo = newMemo))
            _developedPhotos.value = currentList.toMutableList().also { it[idx] = updated }
        }
        viewModelScope.launch {
            repository.updateMemo(photoId, newMemo)
        }
    }
}
