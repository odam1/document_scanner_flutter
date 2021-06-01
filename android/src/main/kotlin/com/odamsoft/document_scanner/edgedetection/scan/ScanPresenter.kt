package com.odamsoft.document_scanner.edgedetection.scan

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Point
import android.hardware.Camera
import android.util.Log
import android.view.SurfaceHolder
import android.widget.Toast
import com.odamsoft.document_scanner.edgedetection.processor.*
import io.reactivex.Observable
import io.reactivex.android.schedulers.AndroidSchedulers
import io.reactivex.schedulers.Schedulers
import org.opencv.core.Size
import java.io.IOException


class ScanPresenter constructor(private val context: Context, private val iView: IScanView.Proxy) :
    SurfaceHolder.Callback, Camera.PictureCallback, Camera.PreviewCallback {
    private val TAG: String = "ScanPresenter"
    private var mCamera: Camera? = null
    private val mSurfaceHolder: SurfaceHolder = iView.getSurfaceView().holder
    private var busy: Boolean = false
    private var isTakingPicture = false

    init {
        mSurfaceHolder.addCallback(this)
    }

    fun start() {
        updateCamera()
    }

    fun stop() {
        mCamera?.stopPreview() ?: Log.d(TAG, "camera null")
    }

    fun takePicture() {
        isTakingPicture = true
        Log.d(TAG, "try to focus")
        mCamera?.autoFocus { b, _ ->
            Log.d(TAG, "focus result: $b")
            mCamera?.takePicture(null, null, this)
        }
    }

    fun changeFlashMode(mode: String) {
        if(mCamera == null) return;
        Log.d(TAG, "Flash mode $mode")
        val flashMode = when (mode) {
            "On" -> Camera.Parameters.FLASH_MODE_ON
            "Off" -> Camera.Parameters.FLASH_MODE_OFF
            "Auto" -> Camera.Parameters.FLASH_MODE_AUTO
            "Torch" -> Camera.Parameters.FLASH_MODE_TORCH
            else -> Camera.Parameters.FLASH_MODE_OFF
        }
        val par = mCamera?.parameters!!
        par.flashMode = flashMode
        mCamera!!.parameters = par
        updateCamera()
    }

    fun updateCamera() {
        if (mCamera == null) {
            initCamera()
            if(mCamera == null) return
        }
        busy = false
        isTakingPicture = false
        mCamera?.stopPreview()
        try {
            mCamera?.setPreviewDisplay(mSurfaceHolder)
        } catch (e: IOException) {
            e.printStackTrace()
            return
        }
        mCamera?.setPreviewCallback(this)
        mCamera?.startPreview()
        iView.getPaperRect().onCornersNotDetected()
    }

    private fun initCamera() {
        try {
            mCamera = Camera.open(Camera.CameraInfo.CAMERA_FACING_BACK)
            mCamera?.enableShutterSound(true)
        } catch (e: RuntimeException) {
            e.stackTrace
            Toast.makeText(context, "cannot open camera, please grant camera", Toast.LENGTH_SHORT)
                .show()
            return
        }

        val param = mCamera?.parameters
        val size = getMaxResolution()
        param?.setPreviewSize(size?.width ?: 1920, size?.height ?: 1080)
        val display = iView.getDisplay()
        val point = Point()
        display.getRealSize(point)
        val displayWidth = minOf(point.x, point.y)
        val displayHeight = maxOf(point.x, point.y)
        val displayRatio = displayWidth.div(displayHeight.toFloat())
        val previewRatio = size?.height?.toFloat()?.div(size.width.toFloat()) ?: displayRatio
        if (displayRatio > previewRatio) {
            val surfaceParams = iView.getSurfaceView().layoutParams
            surfaceParams.height = (displayHeight / displayRatio * previewRatio).toInt()
            iView.getSurfaceView().layoutParams = surfaceParams
        }

        val supportPicSize = mCamera?.parameters?.supportedPictureSizes
        supportPicSize?.sortByDescending { it.width.times(it.height) }
        var pictureSize = supportPicSize?.find {
            it.height.toFloat().div(it.width.toFloat()) - previewRatio < 0.01
        }

        if (null == pictureSize) {
            pictureSize = supportPicSize?.get(0)
        }

        if (null == pictureSize) {
            Log.e(TAG, "can not get picture size")
        } else {
            param?.setPictureSize(pictureSize.width, pictureSize.height)
        }
        val pm = context.packageManager
        if (pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_AUTOFOCUS)) {
            param?.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
            Log.d(TAG, "enabling autofocus")
        } else {
            Log.d(TAG, "autofocus not available")
        }
        param?.flashMode = Camera.Parameters.FLASH_MODE_AUTO

        try {
            mCamera?.parameters = param
        } catch (e: RuntimeException) {
            try {
                mCamera?.parameters?.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
            } catch (e: RuntimeException) {
            }
        }
        mCamera?.setDisplayOrientation(90)
    }

    override fun surfaceCreated(p0: SurfaceHolder) {
        initCamera()
    }

    override fun surfaceChanged(p0: SurfaceHolder, p1: Int, p2: Int, p3: Int) {
        updateCamera()
    }

    override fun surfaceDestroyed(p0: SurfaceHolder) {
        synchronized(this) {
            mCamera?.stopPreview()
            mCamera?.setPreviewCallback(null)
            mCamera?.release()
            mCamera = null
        }
    }

    @SuppressLint("CheckResult")
    override fun onPictureTaken(bytes: ByteArray?, camera: Camera?) {
        Log.d(TAG, "on picture taken")
        if (bytes == null || camera == null) {
            iView.failed()
            Log.d(TAG, "Picture taken error: top")
            return
        }
        try {
            Observable.create<HashMap<String, Any?>> {
                val parameters = camera.parameters
                val width = parameters.previewSize.width.toDouble()
                val height = parameters.previewSize.height.toDouble()
                val size = Size(width, height)

                val data = hashMapOf<String, Any?>()
//                var cropBytes: ByteArray? = null

                val mat = bytesToMat(bytes, size, null, true)
//                val corners = processPicture(mat!!)
//                if (corners != null && corners.corners.size == 4) {
//                    cropBytes = matToBytes(cropPicture(mat, corners.corners))
//                }
                data["image"] = matToBytes(mat!!)
                data["size"] = size
//                data["crop"] = cropBytes
//                data["corners"] = corners
                it.onNext(data)
                it.onComplete()
            }
                .subscribeOn(Schedulers.computation())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe({
                    iView.onImageCaptured(it["image"] as ByteArray, it["size"] as Size, it["crop"] as ByteArray?, it["corners"] as Corners?)
                    //isTakingPicture = false
                }, {
                    iView.failed()
                    Log.d(TAG, "Picture taken error: ${it.message}")
                    //isTakingPicture = false
                }, {
                    //isTakingPicture = false
                })
        } catch (e: Exception) {
            print(e.message)
            iView.failed()
            Log.d(TAG, "Picture taken error: ${e.message}")
            //isTakingPicture = false
        }

    }


    @SuppressLint("CheckResult")
    override fun onPreviewFrame(bytes: ByteArray?, camera: Camera?) {
        if (busy || isTakingPicture || bytes == null || camera == null) {
            return
        }
        Log.d(TAG, "on process start")
        busy = true
        try {
            Observable.create<Corners> {
                val parameters = camera.parameters
                val width = parameters.previewSize.width.toDouble()
                val height = parameters.previewSize.height.toDouble()
                val size = Size(width, height)
                val corners = getDocumentCorners(bytes, size, parameters.previewFormat, true)
                if (corners != null && corners.corners.size == 4) {
                    it.onNext(corners)
                    it.onComplete()
                } else {
                    it.onError(Throwable("paper not detected"))
                }
            }
                .subscribeOn(Schedulers.computation())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe({
                    iView.getPaperRect().onCornersDetected(it)
                    busy = false
                }, {
                    iView.getPaperRect().onCornersNotDetected()
                    busy = false
                }, {
                    busy = false
                })
        } catch (e: Exception) {
            print(e.message)
            busy = false
        }

    }

    private fun getMaxResolution(): Camera.Size? =
        mCamera?.parameters?.supportedPreviewSizes?.maxBy { it.width }
}