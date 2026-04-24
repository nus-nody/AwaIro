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
}
