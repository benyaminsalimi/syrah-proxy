package dev.syrah.syrah_proxy_android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class SyrahProxyAndroidPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var flowEventChannel: EventChannel
    private lateinit var statusEventChannel: EventChannel

    private var flowEventSink: EventChannel.EventSink? = null
    private var statusEventSink: EventChannel.EventSink? = null

    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    private var proxyEngine: ProxyEngine? = null
    private var certificateAuthority: CertificateAuthority? = null

    companion object {
        private const val VPN_REQUEST_CODE = 24601
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.syrah.proxy.android/methods"
        )
        methodChannel.setMethodCallHandler(this)

        flowEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.syrah.proxy.android/flows"
        )
        flowEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                flowEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                flowEventSink = null
            }
        })

        statusEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.syrah.proxy.android/status"
        )
        statusEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                statusEventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        flowEventChannel.setStreamHandler(null)
        statusEventChannel.setStreamHandler(null)
        proxyEngine?.stop()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingResult?.success(true)
            } else {
                pendingResult?.error("VPN_DENIED", "User denied VPN permission", null)
            }
            pendingResult = null
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initialize" -> {
                initialize(result)
            }

            "startProxy" -> {
                val port = call.argument<Int>("port") ?: 8888
                val enableSsl = call.argument<Boolean>("enableSslInterception") ?: true
                val bypassApps = call.argument<List<String>>("bypassApps") ?: emptyList()
                startProxy(port, enableSsl, bypassApps, result)
            }

            "stopProxy" -> {
                stopProxy(result)
            }

            "getProxyStatus" -> {
                getProxyStatus(result)
            }

            "getRootCertificate" -> {
                getRootCertificate(result)
            }

            "exportRootCertificate" -> {
                val format = call.argument<String>("format") ?: "pem"
                exportRootCertificate(format, result)
            }

            "setRules" -> {
                val rules = call.argument<List<Map<String, Any>>>("rules") ?: emptyList()
                setRules(rules, result)
            }

            "pauseFlow" -> {
                val flowId = call.argument<String>("flowId") ?: ""
                pauseFlow(flowId, result)
            }

            "resumeFlow" -> {
                val flowId = call.argument<String>("flowId") ?: ""
                val modRequest = call.argument<Map<String, Any>>("modifiedRequest")
                val modResponse = call.argument<Map<String, Any>>("modifiedResponse")
                resumeFlow(flowId, modRequest, modResponse, result)
            }

            "abortFlow" -> {
                val flowId = call.argument<String>("flowId") ?: ""
                abortFlow(flowId, result)
            }

            "setThrottling" -> {
                val download = call.argument<Int>("downloadBytesPerSecond") ?: 0
                val upload = call.argument<Int>("uploadBytesPerSecond") ?: 0
                val latency = call.argument<Int>("latencyMs") ?: 0
                val packetLoss = call.argument<Double>("packetLossPercent") ?: 0.0
                setThrottling(download, upload, latency, packetLoss, result)
            }

            "requestVpnPermission" -> {
                requestVpnPermission(result)
            }

            "startVpnService" -> {
                startVpnService(result)
            }

            "stopVpnService" -> {
                stopVpnService(result)
            }

            "setBypassApps" -> {
                val apps = call.argument<List<String>>("packageNames") ?: emptyList()
                setBypassApps(apps, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    // MARK: - Implementation Methods

    private fun initialize(result: Result) {
        try {
            val ctx = context ?: throw IllegalStateException("Context not available")

            certificateAuthority = CertificateAuthority(ctx)
            proxyEngine = ProxyEngine(ctx, certificateAuthority!!)
            proxyEngine?.setListener(object : ProxyEngine.ProxyListener {
                override fun onFlowCaptured(flow: Map<String, Any>) {
                    activity?.runOnUiThread {
                        flowEventSink?.success(flow)
                    }
                }

                override fun onStatusChanged(status: Map<String, Any>) {
                    activity?.runOnUiThread {
                        statusEventSink?.success(status)
                    }
                }

                override fun onError(error: String) {
                    activity?.runOnUiThread {
                        statusEventSink?.success(mapOf("error" to error))
                    }
                }
            })

            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun startProxy(port: Int, enableSsl: Boolean, bypassApps: List<String>, result: Result) {
        try {
            proxyEngine?.start(port, enableSsl, bypassApps)
            result.success(true)
        } catch (e: Exception) {
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stopProxy(result: Result) {
        proxyEngine?.stop()
        result.success(true)
    }

    private fun getProxyStatus(result: Result) {
        val status = proxyEngine?.getStatus() ?: mapOf("isRunning" to false)
        result.success(status)
    }

    private fun getRootCertificate(result: Result) {
        try {
            val ca = certificateAuthority
                ?: throw IllegalStateException("Certificate authority not initialized")

            result.success(
                mapOf(
                    "subject" to ca.rootCertificateSubject,
                    "issuer" to ca.rootCertificateIssuer,
                    "serialNumber" to ca.rootCertificateSerialNumber,
                    "fingerprint" to ca.rootCertificateFingerprint,
                    "isCA" to true,
                    "isRootCA" to true
                )
            )
        } catch (e: Exception) {
            result.error("CERT_ERROR", e.message, null)
        }
    }

    private fun exportRootCertificate(format: String, result: Result) {
        try {
            val ca = certificateAuthority
                ?: throw IllegalStateException("Certificate authority not initialized")

            val data = when (format.lowercase()) {
                "pem" -> ca.exportRootCertificate(CertificateAuthority.ExportFormat.PEM)
                "der" -> ca.exportRootCertificate(CertificateAuthority.ExportFormat.DER)
                else -> ca.exportRootCertificate(CertificateAuthority.ExportFormat.PEM)
            }

            result.success(data)
        } catch (e: Exception) {
            result.error("EXPORT_ERROR", e.message, null)
        }
    }

    private fun setRules(rules: List<Map<String, Any>>, result: Result) {
        proxyEngine?.setRules(rules)
        result.success(true)
    }

    private fun pauseFlow(flowId: String, result: Result) {
        proxyEngine?.pauseFlow(flowId)
        result.success(true)
    }

    private fun resumeFlow(
        flowId: String,
        modRequest: Map<String, Any>?,
        modResponse: Map<String, Any>?,
        result: Result
    ) {
        proxyEngine?.resumeFlow(flowId, modRequest, modResponse)
        result.success(true)
    }

    private fun abortFlow(flowId: String, result: Result) {
        proxyEngine?.abortFlow(flowId)
        result.success(true)
    }

    private fun setThrottling(download: Int, upload: Int, latency: Int, packetLoss: Double, result: Result) {
        proxyEngine?.setThrottling(download, upload, latency, packetLoss)
        result.success(true)
    }

    private fun requestVpnPermission(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        val intent = VpnService.prepare(currentActivity)
        if (intent != null) {
            pendingResult = result
            currentActivity.startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // Already have permission
            result.success(true)
        }
    }

    private fun startVpnService(result: Result) {
        try {
            val ctx = context ?: throw IllegalStateException("Context not available")
            val intent = Intent(ctx, SyrahVpnService::class.java)
            ctx.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("VPN_START_ERROR", e.message, null)
        }
    }

    private fun stopVpnService(result: Result) {
        try {
            val ctx = context ?: throw IllegalStateException("Context not available")
            val intent = Intent(ctx, SyrahVpnService::class.java)
            ctx.stopService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("VPN_STOP_ERROR", e.message, null)
        }
    }

    private fun setBypassApps(apps: List<String>, result: Result) {
        proxyEngine?.setBypassApps(apps)
        result.success(true)
    }
}
