package com.example.print_service

import org.junit.Assert.*
import org.junit.Test

class RasterEncoderTest {
    @Test fun packsMostSignificantPixelFirstAndPadsPartialByte() {
        val white = -1
        val black = 0xff000000.toInt()
        val pixels = intArrayOf(black, white, black, white, white, white, white, black, black)
        val bytes = RasterEncoder.encode(9, 1, pixels)
        assertArrayEquals(byteArrayOf(0x1d, 0x76, 0x30, 0, 2, 0, 1, 0, 0xa1.toByte(), 0x80.toByte()), bytes)
    }

    @Test fun transparentPixelsAreWhiteAndRowsAreIndependent() {
        val bytes = RasterEncoder.encode(8, 2, IntArray(16) { if (it < 8) 0x00000000 else 0xff000000.toInt() })
        assertEquals(0, bytes[8].toInt())
        assertEquals(255, bytes[9].toInt() and 255)
    }

    @Test fun encodesBothPosWidthsAndMultiByteHeight() {
        for (width in listOf(384, 576)) {
            val bytes = RasterEncoder.encode(width, 300, IntArray(width * 300) { -1 })
            assertEquals(width / 8, bytes[4].toInt() and 255)
            assertEquals(44, bytes[6].toInt() and 255)
            assertEquals(1, bytes[7].toInt() and 255)
            assertEquals(8 + width / 8 * 300, bytes.size)
            assertTrue(bytes.drop(8).all { it == 0.toByte() })
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsIncompletePixelBuffer() { RasterEncoder.encode(384, 10, IntArray(10)) }
}
