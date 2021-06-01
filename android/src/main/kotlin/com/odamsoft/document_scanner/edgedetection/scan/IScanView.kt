package com.odamsoft.document_scanner.edgedetection.scan

import android.view.Display
import android.view.SurfaceView
import com.odamsoft.document_scanner.edgedetection.processor.Corners
import com.odamsoft.document_scanner.edgedetection.view.PaperRectangle
import org.opencv.core.Size

interface IScanView {
    interface Proxy {
        fun exit()
        fun failed()
        fun getDisplay(): Display
        fun getSurfaceView(): SurfaceView
        fun getPaperRect(): PaperRectangle
        fun onImageCaptured(imageBytes: ByteArray, imageSize: Size, cropBytes: ByteArray?, corners: Corners?)
    }
}