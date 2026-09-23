package com.example.my_first_app

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.my_first_app/image_picker"
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 1001
    private var isOriginalRequested: Boolean = false
    private var isMultipleSelectionRequested: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickImage" || call.method == "pickChatImage" || call.method == "pickMultipleImages") {
                pendingResult = result
                isMultipleSelectionRequested = (call.method == "pickMultipleImages") || (call.method == "pickChatImage") || (call.argument<Boolean>("allowMultiple") == true)
                isOriginalRequested = (call.method == "pickChatImage") || (call.method == "pickMultipleImages") || (call.argument<Boolean>("original") == true)
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    if (isMultipleSelectionRequested) {
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                }
                startActivityForResult(Intent.createChooser(intent, "Select Pictures"), PICK_IMAGE_REQUEST)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val imageList = mutableListOf<Map<String, Any?>>()

                // 1. Check clipData for multiple items selected at once
                if (data.clipData != null) {
                    val count = data.clipData!!.itemCount
                    for (i in 0 until count) {
                        val uri = data.clipData!!.getItemAt(i).uri
                        val itemMap = processUri(uri)
                        if (itemMap != null) {
                            imageList.add(itemMap)
                        }
                    }
                }
                // 2. Check data.data for single item selected
                else if (data.data != null) {
                    val uri = data.data!!
                    val itemMap = processUri(uri)
                    if (itemMap != null) {
                        imageList.add(itemMap)
                    }
                }

                if (imageList.isNotEmpty()) {
                    if (isMultipleSelectionRequested) {
                        pendingResult?.success(imageList)
                    } else {
                        pendingResult?.success(imageList.first())
                    }
                } else {
                    pendingResult?.success(null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    private fun processUri(uri: Uri): Map<String, Any?>? {
        return try {
            if (isOriginalRequested) {
                val inputStream = contentResolver.openInputStream(uri)
                val bytes = inputStream?.readBytes() ?: return null
                val mimeType = contentResolver.getType(uri) ?: "image/jpeg"
                val ext = when {
                    mimeType.contains("png", ignoreCase = true) -> "png"
                    mimeType.contains("webp", ignoreCase = true) -> "webp"
                    mimeType.contains("gif", ignoreCase = true) -> "gif"
                    else -> "jpg"
                }
                mapOf(
                    "bytes" to bytes,
                    "ext" to ext,
                    "mimeType" to mimeType
                )
            } else {
                val compressedData = compressAndResizeImage(uri, maxDimension = 600, quality = 75)
                mapOf(
                    "bytes" to compressedData.first,
                    "ext" to compressedData.second,
                    "mimeType" to "image/jpeg"
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun compressAndResizeImage(uri: Uri, maxDimension: Int, quality: Int): Pair<ByteArray, String> {
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, boundsOptions)
        }

        var sampleSize = 1
        var w = boundsOptions.outWidth
        var h = boundsOptions.outHeight
        while (w / 2 >= maxDimension || h / 2 >= maxDimension) {
            w /= 2
            h /= 2
            sampleSize *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val originalBitmap = contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, decodeOptions)
        } ?: throw Exception("Failed to decode image")

        val scaledBitmap = if (originalBitmap.width > maxDimension || originalBitmap.height > maxDimension) {
            val ratio = Math.min(
                maxDimension.toFloat() / originalBitmap.width,
                maxDimension.toFloat() / originalBitmap.height
            )
            val targetW = Math.max(1, (originalBitmap.width * ratio).toInt())
            val targetH = Math.max(1, (originalBitmap.height * ratio).toInt())
            Bitmap.createScaledBitmap(originalBitmap, targetW, targetH, true)
        } else {
            originalBitmap
        }

        val output = ByteArrayOutputStream()
        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
        return Pair(output.toByteArray(), "jpg")
    }
}
