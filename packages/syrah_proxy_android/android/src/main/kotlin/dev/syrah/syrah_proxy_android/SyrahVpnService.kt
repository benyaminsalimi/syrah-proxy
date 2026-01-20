package dev.syrah.syrah_proxy_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * VPN Service for capturing all device traffic
 */
class SyrahVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = AtomicBoolean(false)
    private var proxyThread: Thread? = null

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "syrah_vpn_channel"
        private const val NOTIFICATION_ID = 1
        private const val VPN_MTU = 1500
        private const val PROXY_HOST = "127.0.0.1"
        private const val PROXY_PORT = 8888

        // VPN tunnel addresses
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val VPN_DNS = "8.8.8.8"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isRunning.get()) {
            return START_STICKY
        }

        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())

        // Establish VPN
        if (establishVpn()) {
            isRunning.set(true)
            startProxyThread()
        } else {
            stopSelf()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun establishVpn(): Boolean {
        return try {
            val builder = Builder()
                .setSession("Syrah Proxy")
                .setMtu(VPN_MTU)
                .addAddress(VPN_ADDRESS, 32)
                .addRoute(VPN_ROUTE, 0)
                .addDnsServer(VPN_DNS)

            // Allow apps to bypass VPN
            // builder.addDisallowedApplication(packageName)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            vpnInterface = builder.establish()
            vpnInterface != null
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun startProxyThread() {
        proxyThread = Thread {
            try {
                val vpnFd = vpnInterface?.fileDescriptor ?: return@Thread
                val vpnInput = FileInputStream(vpnFd)
                val vpnOutput = FileOutputStream(vpnFd)

                val packet = ByteBuffer.allocate(VPN_MTU)

                while (isRunning.get()) {
                    // Read packet from VPN
                    val length = vpnInput.channel.read(packet)
                    if (length > 0) {
                        packet.flip()

                        // Process the packet
                        val processedPacket = processPacket(packet, length)

                        if (processedPacket != null) {
                            // Write processed packet back to VPN
                            vpnOutput.channel.write(processedPacket)
                        }

                        packet.clear()
                    }
                }

                vpnInput.close()
                vpnOutput.close()
            } catch (e: Exception) {
                if (isRunning.get()) {
                    e.printStackTrace()
                }
            }
        }
        proxyThread?.start()
    }

    private fun processPacket(packet: ByteBuffer, length: Int): ByteBuffer? {
        // Parse IP header
        if (length < 20) return null

        val version = (packet.get(0).toInt() shr 4) and 0xF
        if (version != 4) return null // Only IPv4 for now

        val protocol = packet.get(9).toInt() and 0xFF

        when (protocol) {
            OsConstants.IPPROTO_TCP -> {
                return processTcpPacket(packet, length)
            }
            OsConstants.IPPROTO_UDP -> {
                return processUdpPacket(packet, length)
            }
        }

        return null
    }

    private fun processTcpPacket(packet: ByteBuffer, length: Int): ByteBuffer? {
        // For TCP, we need to redirect to our local proxy
        // This is a simplified implementation - a full implementation would
        // handle connection tracking, sequence numbers, etc.

        // Extract destination address and port
        val ipHeaderLength = (packet.get(0).toInt() and 0xF) * 4
        if (length < ipHeaderLength + 20) return null

        val destPort = ((packet.get(ipHeaderLength + 2).toInt() and 0xFF) shl 8) or
                (packet.get(ipHeaderLength + 3).toInt() and 0xFF)

        // Check if this is HTTP/HTTPS traffic
        if (destPort == 80 || destPort == 443) {
            // Redirect to local proxy
            // In a full implementation, we would:
            // 1. Create a TCP connection to our proxy
            // 2. Forward the packet data
            // 3. Return the response
        }

        return null
    }

    private fun processUdpPacket(packet: ByteBuffer, length: Int): ByteBuffer? {
        // Handle DNS queries
        val ipHeaderLength = (packet.get(0).toInt() and 0xF) * 4
        if (length < ipHeaderLength + 8) return null

        val destPort = ((packet.get(ipHeaderLength + 2).toInt() and 0xFF) shl 8) or
                (packet.get(ipHeaderLength + 3).toInt() and 0xFF)

        if (destPort == 53) {
            // Forward DNS query
            return forwardDnsQuery(packet, length, ipHeaderLength)
        }

        return null
    }

    private fun forwardDnsQuery(packet: ByteBuffer, length: Int, ipHeaderLength: Int): ByteBuffer? {
        try {
            val udpHeaderLength = 8
            val dnsStart = ipHeaderLength + udpHeaderLength

            // Extract DNS query
            val dnsQueryLength = length - dnsStart
            val dnsQuery = ByteArray(dnsQueryLength)
            packet.position(dnsStart)
            packet.get(dnsQuery)

            // Forward to real DNS server
            val channel = DatagramChannel.open()
            channel.configureBlocking(true)
            protect(channel.socket()) // Bypass VPN for this socket

            channel.connect(InetSocketAddress(VPN_DNS, 53))
            channel.write(ByteBuffer.wrap(dnsQuery))

            val response = ByteBuffer.allocate(1024)
            val responseLength = channel.read(response)
            channel.close()

            if (responseLength > 0) {
                // Build response packet
                response.flip()
                return buildDnsResponse(packet, response, responseLength)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun buildDnsResponse(
        originalPacket: ByteBuffer,
        dnsResponse: ByteBuffer,
        responseLength: Int
    ): ByteBuffer {
        // Build IP + UDP + DNS response packet
        // This is simplified - a full implementation would properly construct the headers

        val ipHeaderLength = 20
        val udpHeaderLength = 8
        val totalLength = ipHeaderLength + udpHeaderLength + responseLength

        val response = ByteBuffer.allocate(totalLength)

        // IP Header (swap source and destination)
        response.put((0x45).toByte()) // Version + IHL
        response.put(0) // TOS
        response.putShort(totalLength.toShort()) // Total length
        response.putShort(0) // Identification
        response.putShort(0) // Flags + Fragment offset
        response.put(64) // TTL
        response.put(17) // Protocol (UDP)
        response.putShort(0) // Checksum (will calculate later)

        // Swap source and dest addresses
        val srcAddr = ByteArray(4)
        val dstAddr = ByteArray(4)
        originalPacket.position(12)
        originalPacket.get(srcAddr)
        originalPacket.get(dstAddr)
        response.put(dstAddr) // New source = old dest
        response.put(srcAddr) // New dest = old source

        // UDP Header (swap ports)
        val srcPort = originalPacket.getShort(20)
        val dstPort = originalPacket.getShort(22)
        response.putShort(dstPort) // New source port = old dest port
        response.putShort(srcPort) // New dest port = old source port
        response.putShort((udpHeaderLength + responseLength).toShort()) // UDP length
        response.putShort(0) // UDP checksum

        // DNS Response
        val dnsBytes = ByteArray(responseLength)
        dnsResponse.get(dnsBytes)
        response.put(dnsBytes)

        response.flip()
        return response
    }

    private fun stopVpn() {
        isRunning.set(false)
        proxyThread?.interrupt()
        proxyThread = null
        vpnInterface?.close()
        vpnInterface = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Syrah VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Syrah proxy is capturing network traffic"
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Syrah Proxy")
                .setContentText("Capturing network traffic")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Syrah Proxy")
                .setContentText("Capturing network traffic")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .build()
        }
    }
}
