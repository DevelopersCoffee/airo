import Flutter
import Foundation

/// Gemini Nano Plugin for Flutter iOS
/// Provides device capability information for on-device AI inference
/// Note: Gemini Nano is Android-only, but this plugin provides device info and memory detection
public class GeminiNanoPlugin: NSObject, FlutterPlugin {
    
    private static let channelName = "com.airo.gemini_nano"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = GeminiNanoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            // Gemini Nano is Android-only
            result(false)
        case "getDeviceInfo":
            getDeviceInfo(result: result)
        case "getMemoryInfo":
            getMemoryInfo(result: result)
        case "getCapabilities":
            getCapabilities(result: result)
        case "initialize":
            // Not available on iOS
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Gemini Nano is not available on iOS",
                details: nil
            ))
        case "generateContent", "generateContentStream":
            // Not available on iOS
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Gemini Nano is not available on iOS",
                details: nil
            ))
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Get device information
    private func getDeviceInfo(result: FlutterResult) {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        let deviceInfo: [String: Any] = [
            "manufacturer": "Apple",
            "model": deviceModel,
            "brand": "Apple",
            "device": UIDevice.current.model,
            "product": UIDevice.current.name,
            "release": UIDevice.current.systemVersion,
            "sdkVersion": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            "isPixel": false,
            "supportsGeminiNano": false
        ]
        result(deviceInfo)
    }
    
    /// Get device memory information
    /// Uses ProcessInfo for total RAM and mach APIs for available memory
    private func getMemoryInfo(result: FlutterResult) {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let availableBytes = getAvailableMemory()
        
        // Low memory threshold (similar to Android's concept)
        // iOS doesn't have an exact equivalent, so we use 15% of total as threshold
        let threshold = totalBytes / 100 * 15
        let lowMemory = availableBytes < threshold
        
        let memoryData: [String: Any] = [
            "totalBytes": totalBytes,
            "availableBytes": availableBytes,
            "threshold": threshold,
            "lowMemory": lowMemory
        ]
        result(memoryData)
    }
    
    /// Get available memory using mach APIs
    private func getAvailableMemory() -> UInt64 {
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        
        let kernResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    $0,
                    &infoCount
                )
            }
        }
        
        guard kernResult == KERN_SUCCESS else {
            // Fallback: estimate 50% of total memory as available
            return ProcessInfo.processInfo.physicalMemory / 2
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let freeMemory = UInt64(vmStats.free_count) * pageSize
        let inactiveMemory = UInt64(vmStats.inactive_count) * pageSize
        
        // Available memory = free + inactive (can be reclaimed)
        return freeMemory + inactiveMemory
    }
    
    /// Get Gemini Nano capabilities (returns empty for iOS)
    private func getCapabilities(result: FlutterResult) {
        // iOS doesn't support Gemini Nano
        let capabilities: [String: Any] = [
            "summarization": false,
            "imageDescription": false,
            "proofreading": false,
            "rewriting": false,
            "chat": false,
            "maxTokens": 0,
            "supportedLanguages": [] as [String]
        ]
        result(capabilities)
    }
}

