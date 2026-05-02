package io.awairo.domain.repository

import io.awairo.domain.model.Photo
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

interface PhotoRepository {
    suspend fun save(photo: Photo)
    suspend fun findById(id: String): Photo?
    suspend fun findByLocalDate(date: LocalDate): List<Photo>
    suspend fun findDevelopedAsOf(now: Instant): List<Photo>
    suspend fun delete(id: String)

    /** 全件を撮影日時の新しい順で返す（現像済み・未現像どちらも含む）。 */
    suspend fun findAllOrderByCapturedAtDesc(): List<Photo>

    /** 指定 ID の写真のメモを更新する。 */
    suspend fun updateMemo(id: String, memo: String)
}
