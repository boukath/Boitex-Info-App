package com.boitexinfo.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build // ✅ ADDED: Required for version check
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    // 1. Channel Name: Must match the string in ZebraService.dart
    private val CHANNEL = "com.boitexinfo.app/zebra_scanner"

    // 2. Intent Action: Must match the configuration in the DataWedge App on the device
    private val SCAN_INTENT = "com.boitexinfo.app.SCAN"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 3. Set up the EventChannel to bridge Native Android -> Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var receiver: BroadcastReceiver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // When Flutter starts listening, register the broadcast receiver
                    receiver = createReceiver(events)
                    val filter = IntentFilter()
                    filter.addAction(SCAN_INTENT)
                    filter.addCategory(Intent.CATEGORY_DEFAULT)

                    // ✅ FIXED: Android 14 (API 34) requires specifying if the receiver is exported
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                    } else {
                        context.registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    // When Flutter stops listening, unregister to prevent memory leaks
                    if (receiver != null) {
                        context.unregisterReceiver(receiver)
                        receiver = null
                    }
                }
            }
        )
    }

    // 4. Create the receiver that listens for the DataWedge broadcast
    private fun createReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val action = intent.action
                if (action == SCAN_INTENT) {
                    // 5. Extract the barcode data using the standard DataWedge key
                    val scanData = intent.getStringExtra("com.symbol.datawedge.data_string")
                    if (scanData != null) {
                        // Send data to Flutter
                        events?.success(scanData)
                    }
                }
            }
        }
    }
}