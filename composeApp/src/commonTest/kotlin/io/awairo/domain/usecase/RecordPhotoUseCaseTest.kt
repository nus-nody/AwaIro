package io.awairo.domain.usecase

import io.awairo.FakePhotoRepository
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RecordPhotoUseCaseTest {

    private val repo = FakePhotoRepository()
    private val useCase = RecordPhotoUseCase(repo)

    @Test
    fun `今日の写真がないとき、Successを返してDBに保存する`() = runTest {
        val result = useCase.execute(
            absoluteImagePath = "/data/photos/abc.jpg",
            memo = "テストメモ"
        )
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        assertEquals(1, repo.savedPhotos.size)
        assertEquals("photos/abc.jpg", repo.savedPhotos[0].imagePath)
        assertEquals("テストメモ", repo.savedPhotos[0].memo)
    }

    @Test
    fun `今日すでに写真があるとき、AlreadyTakenTodayを返す`() = runTest {
        repo.addPhotoForToday()
        val result = useCase.execute(
            absoluteImagePath = "/data/photos/xyz.jpg",
            memo = ""
        )
        assertEquals(RecordPhotoUseCase.Result.AlreadyTakenToday, result)
        assertEquals(1, repo.savedPhotos.size) // 新しく追加されていない
    }

    @Test
    fun `developedAtはcapturedAtの24時間後になる`() = runTest {
        val result = useCase.execute("/data/photos/abc.jpg", "")
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        val photo = result.photo
        val diffMillis = photo.developedAt.toEpochMilliseconds() - photo.capturedAt.toEpochMilliseconds()
        assertEquals(24 * 60 * 60 * 1000L, diffMillis)
    }

    @Test
    fun `メモが空文字でも保存できる`() = runTest {
        val result = useCase.execute("/data/photos/abc.jpg", "")
        assertTrue(result is RecordPhotoUseCase.Result.Success)
        assertEquals("", result.photo.memo)
    }
}
