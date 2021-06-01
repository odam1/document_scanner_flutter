package com.odamsoft.document_scanner.edgedetection.processor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.lang.Exception

fun processPicture(previewFrame: Mat): Corners? {
    val contours = findContours(previewFrame)
    return getCorners(contours, previewFrame.size())
}

fun cropPicture(picture: Mat, pts: List<Point>): Mat {
    Log.d("PaperProcessor", "Crop picture")
    val tl = pts[0]
    val tr = pts[1]
    val br = pts[2]
    val bl = pts[3]

    val widthA = Math.sqrt(Math.pow(br.x - bl.x, 2.0) + Math.pow(br.y - bl.y, 2.0))
    val widthB = Math.sqrt(Math.pow(tr.x - tl.x, 2.0) + Math.pow(tr.y - tl.y, 2.0))

    val dw = Math.max(widthA, widthB)
    val maxWidth = java.lang.Double.valueOf(dw).toInt()

    val heightA = Math.sqrt(Math.pow(tr.x - br.x, 2.0) + Math.pow(tr.y - br.y, 2.0))
    val heightB = Math.sqrt(Math.pow(tl.x - bl.x, 2.0) + Math.pow(tl.y - bl.y, 2.0))

    val dh = Math.max(heightA, heightB)
    val maxHeight = java.lang.Double.valueOf(dh).toInt()

    val croppedPic = Mat(maxHeight, maxWidth, CvType.CV_8UC4)

    val src_mat = Mat(4, 1, CvType.CV_32FC2)
    val dst_mat = Mat(4, 1, CvType.CV_32FC2)

    src_mat.put(0, 0, tl.x, tl.y, tr.x, tr.y, br.x, br.y, bl.x, bl.y)
    dst_mat.put(0, 0, 0.0, 0.0, dw, 0.0, dw, dh, 0.0, dh)

    val m = Imgproc.getPerspectiveTransform(src_mat, dst_mat)

    Imgproc.warpPerspective(picture, croppedPic, m, croppedPic.size())
    m.release()
    src_mat.release()
    dst_mat.release()

    return croppedPic
}

fun cropPicture(imageBytes: ByteArray, size: Size?, format: Int?, corners: List<Point>, rotate: Boolean): ByteArray? {
    val img = bytesToMat(imageBytes, size, format, rotate) ?: return null
    val cropMat = cropPicture(img, corners)
    return matToBytes(cropMat)
}

fun getDocumentCorners(imageBytes: ByteArray, size: Size?, format: Int?, rotate: Boolean): Corners? {
    val img = bytesToMat(imageBytes, size, format, rotate) ?: return null
    return  processPicture(img)
}


//
//fun enhancePicture(src: Bitmap?): Bitmap {
//    val src_mat = Mat()
//    Utils.bitmapToMat(src, src_mat)
//    Imgproc.cvtColor(src_mat, src_mat, Imgproc.COLOR_RGBA2GRAY)
//    Imgproc.adaptiveThreshold(
//        src_mat,
//        src_mat,
//        255.0,
//        Imgproc.ADAPTIVE_THRESH_MEAN_C,
//        Imgproc.THRESH_BINARY,
//        15,
//        15.0
//    )
//    val result = Bitmap.createBitmap(src?.width ?: 1080, src?.height ?: 1920, Bitmap.Config.RGB_565)
//    Utils.matToBitmap(src_mat, result, true)
//    src_mat.release()
//    return result
//}

fun bytesToMat(byteArray: ByteArray, size: Size?, format: Int?, rotate: Boolean): Mat? {
    try {
        if(format == null || size == null) {
            val mat = Imgcodecs.imdecode(MatOfByte(*byteArray), Imgcodecs.CV_LOAD_IMAGE_UNCHANGED)
            if(rotate) Core.rotate(mat, mat, Core.ROTATE_90_CLOCKWISE)
            Imgproc.cvtColor(mat, mat, Imgproc.COLOR_RGB2BGRA)
            return mat
        }else {
            val width = size.width.toInt()
            val height = size.height.toInt()
            val yuv = YuvImage(byteArray, format, width, height, null)
            val out = ByteArrayOutputStream()
            yuv.compressToJpeg(Rect(0, 0, width, height), 100, out)
            val bytes = out.toByteArray()
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

            val mat = Mat()
            Utils.bitmapToMat(bitmap, mat)
            bitmap.recycle()
            if(rotate) Core.rotate(mat, mat, Core.ROTATE_90_CLOCKWISE)
            try {
                out.close()
            } catch (e: IOException) {
                e.printStackTrace()
            }
            return mat
        }
    }catch(e: Exception) {
        e.printStackTrace()
    }
    return null
}

fun matToBytes(mat: Mat): ByteArray {
    val bitmap = Bitmap.createBitmap(mat.width(), mat.height(), Bitmap.Config.ARGB_8888)
    Utils.matToBitmap(mat, bitmap)

    val stream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
    val bytes = stream.toByteArray()
    bitmap.recycle()
    return bytes
}

private fun findContours(src: Mat): ArrayList<MatOfPoint> {

    val grayImage: Mat
    val cannedImage: Mat
    val kernel: Mat = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(9.0, 9.0))
    val dilate: Mat
    val size = Size(src.size().width, src.size().height)
    grayImage = Mat(size, CvType.CV_8UC4)
    cannedImage = Mat(size, CvType.CV_8UC1)
    dilate = Mat(size, CvType.CV_8UC1)

    Imgproc.cvtColor(src, grayImage, Imgproc.COLOR_BGR2GRAY)
    Imgproc.GaussianBlur(grayImage, grayImage, Size(5.0, 5.0), 0.0)
    Imgproc.threshold(grayImage, grayImage, 20.0, 255.0, Imgproc.THRESH_TRIANGLE)
    Imgproc.Canny(grayImage, cannedImage, 75.0, 200.0)
    Imgproc.dilate(cannedImage, dilate, kernel)
    val contours = ArrayList<MatOfPoint>()
    val hierarchy = Mat()
    Imgproc.findContours(
        dilate,
        contours,
        hierarchy,
        Imgproc.RETR_TREE,
        Imgproc.CHAIN_APPROX_SIMPLE
    )
    contours.sortByDescending { p: MatOfPoint -> Imgproc.contourArea(p) }
    hierarchy.release()
    grayImage.release()
    cannedImage.release()
    kernel.release()
    dilate.release()

    return contours
}

private fun getCorners(contours: ArrayList<MatOfPoint>, size: Size): Corners? {
    val indexTo = when (contours.size) {
        in 0..5 -> contours.size - 1
        else -> 4
    }
    for (index in 0..contours.size) {
        if (index in 0..indexTo) {
            val c2f = MatOfPoint2f(*contours[index].toArray())
            val peri = Imgproc.arcLength(c2f, true)
            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(c2f, approx, 0.03 * peri, true)
            //val area = Imgproc.contourArea(approx)
            val points = approx.toArray().asList()
            val convex = MatOfPoint()
            approx.convertTo(convex, CvType.CV_32S)
            // select biggest 4 angles polygon
            if (points.size == 4 && Imgproc.isContourConvex(convex)) {
                val foundPoints = sortPoints(points)
                return Corners(foundPoints, size)
            }
        } else {
            return null
        }
    }

    return null
}

private fun sortPoints(points: List<Point>): List<Point> {
    val p0 = points.minBy { point -> point.x + point.y } ?: Point()
    val p1 = points.minBy { point -> point.y - point.x } ?: Point()
    val p2 = points.maxBy { point -> point.x + point.y } ?: Point()
    val p3 = points.maxBy { point -> point.y - point.x } ?: Point()
    return listOf(p0, p1, p2, p3)
}