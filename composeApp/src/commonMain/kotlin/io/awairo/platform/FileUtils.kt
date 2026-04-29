package io.awairo.platform

/**
 * 撮影した画像ファイルを削除する。
 * キャンセル時・DB保存失敗時のクリーンアップに使う。
 */
expect fun deletePhotoFile(absolutePath: String)
