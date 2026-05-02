package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlin.time.Duration

/**
 * 全写真を新しい順で取得し、各写真の現像状態を `now` 基準で解決して返す。
 */
class DevelopPhotoUseCase(
    private val repository: PhotoRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(): List<DevelopedPhoto> {
        val now = clock.now()
        return repository.findAllOrderByCapturedAtDesc().map { photo ->
            DevelopedPhoto(
                photo = photo,
                isDeveloped = photo.isDeveloped(now),
                remaining = photo.remainingUntilDeveloped(now)
            )
        }
    }
}

/** 表示時点で解決済みの「現像状態付き写真」。 */
data class DevelopedPhoto(
    val photo: Photo,
    val isDeveloped: Boolean,
    val remaining: Duration
) {
    /** [photo] の id への簡易アクセサ。equals/hashCode には含まれない。 */
    val id: String get() = photo.id
}
