package io.awairo.platform.camera

/**
 * プラットフォーム固有のカメラ制御クラス。
 * Android: CameraX / iOS: AVFoundation
 */
expect class CameraController {
    /** カメラパーミッションが許可されているか */
    fun hasPermission(): Boolean
    /**
     * 現在のフレームを撮影してファイルに保存する。
     * @return 画像の絶対パス（例: "/data/.../photos/abc.jpg"）、失敗時は null
     */
    suspend fun capture(): String?
    /** カメラリソースを解放する（ライフサイクル終了時に呼ぶ） */
    fun release()
}
