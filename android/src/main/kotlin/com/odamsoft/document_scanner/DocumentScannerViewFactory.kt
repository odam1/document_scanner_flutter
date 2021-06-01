package com.odamsoft.document_scanner

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.view.Display
import android.view.SurfaceView
import android.view.View
import android.widget.RelativeLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.odamsoft.document_scanner.edgedetection.processor.Corners
import com.odamsoft.document_scanner.edgedetection.processor.cropPicture
import com.odamsoft.document_scanner.edgedetection.processor.processPicture
import com.odamsoft.document_scanner.edgedetection.scan.IScanView
import com.odamsoft.document_scanner.edgedetection.scan.ScanPresenter
import com.odamsoft.document_scanner.edgedetection.view.PaperRectangle
import io.flutter.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.reactivex.Scheduler
import io.reactivex.schedulers.Schedulers
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class DocumentScannerViewFactory(private val messenger: BinaryMessenger): PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.odamsoft.document_scanner"
    }

    private var mDocumentScannerView: DocumentScannerView? = null

    private var binding: ActivityPluginBinding? = null
    fun getBinding() : ActivityPluginBinding? = binding
    fun setBinding(binding: ActivityPluginBinding?) {
        this.binding = binding
    }

    fun onStart() {
        mDocumentScannerView?.onStart()
    }

    fun onStop() {
        mDocumentScannerView?.onStop()
    }

    fun onDestroy() {
        mDocumentScannerView = null
    }

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        mDocumentScannerView = DocumentScannerView(this, this.messenger, context!!, viewId, args)
        return mDocumentScannerView!!
    }

}

internal class DocumentScannerView(private val documentScannerViewFactory: DocumentScannerViewFactory,  messenger: BinaryMessenger, private val context: Context, viewId: Int, args: Any?): PlatformView,
    MethodChannel.MethodCallHandler, IScanView.Proxy, PluginRegistry.RequestPermissionsResultListener {
    private val REQUEST_CAMERA_PERMISSION = 0
    private val TAG = "DocumentScannerViewFactory"

    private val channel: MethodChannel

    private val relativeLayout = RelativeLayout(context)
    private val surfaceView = SurfaceView(context)
    private val paperRectangle = PaperRectangle(context)

    private val scanPresenter = ScanPresenter(context, this)

    init {
        documentScannerViewFactory.getBinding()?.addRequestPermissionsResultListener(this)

        //
        relativeLayout.addView(surfaceView)
        relativeLayout.addView(paperRectangle)

        //
        channel = MethodChannel(messenger, DocumentScannerViewFactory.METHOD_CHANNEL_NAME+"#$viewId")
        channel.setMethodCallHandler(this)

        //
        prepare()

    }
    override fun getView(): View {
        return relativeLayout
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        scanPresenter.stop()
        documentScannerViewFactory.getBinding()?.removeRequestPermissionsResultListener(this)
    }

    fun onStart() {
        scanPresenter.start()
    }

    fun onStop() {
        scanPresenter.stop()
    }

    private fun prepare() {
        val binding = documentScannerViewFactory.getBinding()
        if (binding == null) {
            failed()
            return
        }
        if (ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.CAMERA
            ) != PackageManager.PERMISSION_GRANTED
        ) {

            ActivityCompat.requestPermissions(
                binding.activity,
                arrayOf(
                    android.Manifest.permission.CAMERA
                ),
                REQUEST_CAMERA_PERMISSION
            )
        }
        else{
            //scanPresenter.initCamera()
            scanPresenter.updateCamera()
        }

    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "captureImage" -> {
                scanPresenter.takePicture()
            }
            "changeFlashMode" -> {
                val mode: String = call.arguments as String
                scanPresenter.changeFlashMode(mode)
            }
            "refreshCamera" -> {
                //scanPresenter.initCamera()
                scanPresenter.updateCamera()
            }
            "dispose" -> {
                dispose()
            }

        }
        result.success(null)
    }



    override fun exit() {
        dispose()
    }

    override fun failed() {
        Log.d(TAG, "Scanner failed")
        channel.invokeMethod("failed", null)
    }

    override fun getDisplay(): Display =  this.context.display!!

    override fun getSurfaceView(): SurfaceView = surfaceView

    override fun getPaperRect(): PaperRectangle = paperRectangle

    override fun onImageCaptured(imageBytes: ByteArray, imageSize: Size, cropBytes: ByteArray?, corners: Corners?) {
        val hashMap = hashMapOf<String, Any?>()
        hashMap["initialImage"] = imageBytes
        hashMap["initialImageSize"] = listOf(imageSize.width, imageSize.height)
        hashMap["corners"] = corners?.corners?.map { listOf(it.x, it.y) }
        hashMap["cropImage"] = cropBytes
        channel.invokeMethod("onCapture", hashMap)
    }


    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>?,
        grantResults: IntArray?
    ): Boolean {

        if (requestCode == REQUEST_CAMERA_PERMISSION) {
            if (permissions != null && grantResults != null && grantResults[permissions.indexOf(android.Manifest.permission.CAMERA)] == PackageManager.PERMISSION_GRANTED) {
                //scanPresenter.initCamera()
                scanPresenter.updateCamera()
                return true
            }else {
                failed()
            }
        }
        return false

    }


}