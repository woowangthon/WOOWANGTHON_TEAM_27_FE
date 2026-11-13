package com.liferadar.liferadar

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Build
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Network-constrained persisted job. Never assumes an exact wall-clock alarm. */
class ContestCollectionJob : JobService() {
    companion object {
        const val CHANNEL = "liferadar/contest_background"
        const val JOB_ID = 270713
        val collecting = AtomicBoolean(false)
        private const val PREFS = "liferadar_contest_scheduler"
        fun schedule(context: Context, callback: Long): Boolean {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong("callback", callback).apply()
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            // Do not reset the periodic schedule every time the UI is launched.
            if (scheduler.allPendingJobs.any { it.id == JOB_ID }) return true
            val builder = JobInfo.Builder(JOB_ID, ComponentName(context, ContestCollectionJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setPeriodic(TimeUnit.HOURS.toMillis(6), TimeUnit.HOURS.toMillis(1))
            } else {
                builder.setPeriodic(TimeUnit.HOURS.toMillis(6))
            }
            return scheduler.schedule(builder.build()) == JobScheduler.RESULT_SUCCESS
        }
    }
    private var engine: FlutterEngine? = null
    private var parameters: JobParameters? = null
    private var ownsCollection = false
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish(true) }

    override fun onStartJob(params: JobParameters): Boolean {
        if (!collecting.compareAndSet(false, true)) return false
        ownsCollection = true
        Log.i("LifeRadarContestJob", "Starting periodic contest due check")
        try {
            val callback = getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("callback", -1)
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val info = FlutterCallbackInformation.lookupCallbackInformation(callback)
            if (info == null) { disposeEngine(); return false }
            parameters = params
            val running = FlutterEngine(applicationContext)
            engine = running
            MethodChannel(running.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "finished") {
                    Log.i("LifeRadarContestJob", "Dart finished: success=${call.argument<Boolean>("success")}, updated=${call.argument<Boolean>("updated")}, count=${call.argument<Number>("count")}")
                    result.success(null)
                    val retry = call.argument<Boolean>("success") != true
                    handler.post { finish(retry) }
                } else result.notImplemented()
            }
            handler.postDelayed(timeout, TimeUnit.MINUTES.toMillis(8))
            running.dartExecutor.executeDartCallback(DartExecutor.DartCallback(assets, loader.findAppBundlePath(), info))
            return true
        } catch (error: Exception) {
            Log.w("LifeRadarContestJob", "Unable to run background collector", error)
            finish(true)
            return false
        }
    }
    private fun disposeEngine() {
        handler.removeCallbacks(timeout)
        engine?.destroy()
        engine = null
        if (ownsCollection) collecting.set(false)
        ownsCollection = false
    }
    private fun finish(retry: Boolean) {
        val job = parameters
        parameters = null
        disposeEngine()
        if (job != null) jobFinished(job, retry)
    }
    override fun onStopJob(params: JobParameters): Boolean {
        parameters = null
        disposeEngine()
        return true
    }
    override fun onDestroy() {
        disposeEngine()
        super.onDestroy()
    }
}
