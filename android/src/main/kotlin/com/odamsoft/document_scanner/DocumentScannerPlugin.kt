package com.odamsoft.document_scanner

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.odamsoft.document_scanner.edgedetection.processor.*

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.reactivex.Observable
import io.reactivex.android.schedulers.AndroidSchedulers
import io.reactivex.schedulers.Schedulers
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import java.io.ByteArrayOutputStream

/** DocumentScannerPlugin */
class DocumentScannerPlugin: FlutterPlugin, ActivityAware, LifecycleEventObserver, MethodChannel.MethodCallHandler {

    private var documentScannerViewFactory: DocumentScannerViewFactory? = null

    private var lifecycle: Lifecycle? = null


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        documentScannerViewFactory = DocumentScannerViewFactory(flutterPluginBinding.binaryMessenger)
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            DocumentScannerViewFactory.METHOD_CHANNEL_NAME+"#view",
            documentScannerViewFactory
        )

        //
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, DocumentScannerViewFactory.METHOD_CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        //initialise opencv
        OpenCVLoader.initDebug()
    }


    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {

    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        documentScannerViewFactory?.setBinding(binding)
        val reference = binding.lifecycle as HiddenLifecycleReference
        lifecycle = reference.lifecycle
        lifecycle?.addObserver(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        documentScannerViewFactory?.setBinding(null)
        lifecycle?.removeObserver(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        documentScannerViewFactory?.setBinding(binding)

        lifecycle?.removeObserver(this)
        val reference = binding.lifecycle as HiddenLifecycleReference
        lifecycle = reference.lifecycle
        lifecycle?.addObserver(this)
    }

    override fun onDetachedFromActivity() {
        documentScannerViewFactory?.setBinding(null)
        lifecycle?.removeObserver(this)
    }

    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        when (event) {
            Lifecycle.Event.ON_CREATE -> {}
            Lifecycle.Event.ON_START -> {
                documentScannerViewFactory?.onStart()
            }
            Lifecycle.Event.ON_RESUME -> {}
            Lifecycle.Event.ON_PAUSE -> {}
            Lifecycle.Event.ON_STOP -> {
                documentScannerViewFactory?.onStop()
            }
            Lifecycle.Event.ON_DESTROY -> {
                documentScannerViewFactory?.onDestroy()
            }
            Lifecycle.Event.ON_ANY -> {}
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "cropPicture" -> {
                cropImage(call, result)
                return
            }
            "detectPaper" -> {
                detectPaper(call, result)
                return
            }

        }
        result.success(null)
    }


    @SuppressLint("CheckResult")
    private fun cropImage(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as HashMap<*, *>
        val bytes = data["bytes"] as ByteArray
        //val size = Size(data["size"] as DoubleArray)
        val corners = (data["corners"] as List<*>).map { Point((it as DoubleArray)[0], it[1]) }

        try {
            Observable.create<ByteArray> {
                val cropBytes = cropPicture(bytes, null, null, corners, false)
                if(cropBytes != null) {
                    it.onNext(cropBytes)
                    it.onComplete()
                }else{
                    it.onError(Throwable("Cropping failed"))
                }

            }
                .subscribeOn(Schedulers.computation())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe({
                   result.success(it)
                }, {
                    result.success(null)
                }, {

                })
        } catch (e: Exception) {
            print(e.message)
            result.success(null)
        }


    }

    @SuppressLint("CheckResult")
    private fun detectPaper(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as HashMap<*, *>
        val bytes = data["bytes"] as ByteArray
        //val size = Size(data["size"] as DoubleArray)

        try {
            Observable.create<Map<String, Any>> { emitter ->
                val mat = bytesToMat(bytes, null, null, false)
                val corners = processPicture(mat!!)
                if (corners != null && corners.corners.size == 4) {
                    val cropBytes = matToBytes(cropPicture(mat, corners.corners))
                    emitter.onNext(mapOf("bytes" to cropBytes, "corners" to corners.corners.map { listOf(it.x, it.y) }))
                    emitter.onComplete()
                    return@create
                }
                emitter.onError(Throwable("Paper detection failed"))

            }
                .subscribeOn(Schedulers.computation())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe({
                    result.success(it)
                }, {
                    result.success(null)
                }, {

                })
        } catch (e: Exception) {
            print(e.message)
            result.success(null)
        }


    }

}
