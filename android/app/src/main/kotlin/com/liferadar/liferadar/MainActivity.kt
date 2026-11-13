package com.liferadar.liferadar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ownsCollection = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ContestCollectionJob.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val handle = call.argument<Number>("callbackHandle")?.toLong()
                        if (handle == null) result.error("handle", "Missing callback", null)
                        else result.success(ContestCollectionJob.schedule(this, handle))
                    }
                    "claim" -> {
                        val acquired = ContestCollectionJob.collecting.compareAndSet(false, true)
                        if (acquired) ownsCollection = true
                        result.success(acquired)
                    }
                    "release" -> {
                        if (ownsCollection) ContestCollectionJob.collecting.set(false)
                        ownsCollection = false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (ownsCollection) ContestCollectionJob.collecting.set(false)
        ownsCollection = false
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
