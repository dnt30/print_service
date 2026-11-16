package com.example.print_service

/** Pure ESC/POS packing, kept independent of Android so the wire format can be tested. */
object RasterEncoder {
    fun encode(width: Int, height: Int, pixels: IntArray): ByteArray {
        require(width in 1..65535 && height in 1..65535)
        require(pixels.size == width * height)
        val widthBytes = (width + 7) / 8
        val packet = ByteArray(8 + widthBytes * height)
        packet[0] = 0x1d; packet[1] = 0x76; packet[2] = 0x30
        packet[4] = (widthBytes and 255).toByte(); packet[5] = (widthBytes shr 8).toByte()
        packet[6] = (height and 255).toByte(); packet[7] = (height shr 8).toByte()
        for (y in 0 until height) for (x in 0 until width) {
            if (isInk(pixels[y * width + x])) {
                val index = 8 + y * widthBytes + x / 8
                packet[index] = (packet[index].toInt() or (0x80 shr (x % 8))).toByte()
            }
        }
        return packet
    }

    fun isInk(argb: Int): Boolean {
        val alpha = argb ushr 24
        val red = (argb ushr 16) and 255
        val green = (argb ushr 8) and 255
        val blue = argb and 255
        return alpha > 127 && (red * 299 + green * 587 + blue * 114) / 1000 < 170
    }
}
