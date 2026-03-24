package com.industrial.molinos_app

import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.industrial.molinos_app/nfc_hce"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNfcAvailable" -> {
                        val nfcAdapter = NfcAdapter.getDefaultAdapter(this)
                        result.success(nfcAdapter != null && nfcAdapter.isEnabled)
                    }
                    "isHceSupported" -> {
                        val hasHce = packageManager.hasSystemFeature(
                            PackageManager.FEATURE_NFC_HOST_CARD_EMULATION
                        )
                        result.success(hasHce)
                    }
                    "startHce" -> {
                        val token = call.argument<String>("token") ?: ""
                        NfcHceService.currentToken = token
                        NfcHceService.isActive = true
                        result.success(true)
                    }
                    "stopHce" -> {
                        NfcHceService.isActive = false
                        NfcHceService.currentToken = ""
                        result.success(true)
                    }
                    "updateHceToken" -> {
                        val token = call.argument<String>("token") ?: ""
                        NfcHceService.currentToken = token
                        result.success(true)
                    }
                    "isHceActive" -> {
                        result.success(NfcHceService.isActive)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
