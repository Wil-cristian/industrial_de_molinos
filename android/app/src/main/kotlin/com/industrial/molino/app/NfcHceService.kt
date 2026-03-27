package com.industrial.molino.app

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import java.io.ByteArrayOutputStream

/**
 * Host Card Emulation (HCE) service.
 *
 * Makes the Android phone act as an NFC tag.
 * When an employee's phone reads this device, it receives the
 * currently configured attendance checkpoint token.
 *
 * The token is set from Flutter via MethodChannel and contains
 * a JSON payload with checkpoint_id + rotating code + timestamp.
 */
class NfcHceService : HostApduService() {

    companion object {
        // AID for our custom attendance app (category "other")
        // F0 prefix = proprietary, followed by app-specific bytes
        const val AID = "F04D4F4C494E4F53" // "F0" + hex("MOLINOS")

        // APDU commands
        private val SELECT_AID_HEADER = byteArrayOf(
            0x00.toByte(), // CLA
            0xA4.toByte(), // INS (SELECT)
            0x04.toByte(), // P1 (select by name)
            0x00.toByte()  // P2
        )

        private val SUCCESS_SW = byteArrayOf(0x90.toByte(), 0x00.toByte()) // SW1 SW2 = OK
        private val FAILURE_SW = byteArrayOf(0x6F.toByte(), 0x00.toByte()) // SW1 SW2 = Error

        // Current token data set from Flutter
        @Volatile
        var currentToken: String = ""

        @Volatile
        var isActive: Boolean = false
    }

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        if (!isActive || currentToken.isEmpty()) {
            return FAILURE_SW
        }

        // Check if this is a SELECT AID command
        if (isSelectAidApdu(commandApdu)) {
            // Return the token data + success status word
            val tokenBytes = currentToken.toByteArray(Charsets.UTF_8)
            return concatArrays(tokenBytes, SUCCESS_SW)
        }

        // For any other APDU, also return token data (simple protocol)
        val tokenBytes = currentToken.toByteArray(Charsets.UTF_8)
        return concatArrays(tokenBytes, SUCCESS_SW)
    }

    override fun onDeactivated(reason: Int) {
        // NFC link lost or another AID selected
    }

    private fun isSelectAidApdu(apdu: ByteArray): Boolean {
        if (apdu.size < 4) return false
        return apdu[0] == SELECT_AID_HEADER[0] &&
               apdu[1] == SELECT_AID_HEADER[1] &&
               apdu[2] == SELECT_AID_HEADER[2] &&
               apdu[3] == SELECT_AID_HEADER[3]
    }

    private fun concatArrays(a: ByteArray, b: ByteArray): ByteArray {
        val output = ByteArrayOutputStream()
        output.write(a)
        output.write(b)
        return output.toByteArray()
    }
}
