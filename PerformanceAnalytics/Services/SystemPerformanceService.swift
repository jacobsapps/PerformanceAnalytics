//
//  SystemPerformanceService.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import Foundation
import UIKit
import os

class SystemPerformanceService {
    
    static let shared = SystemPerformanceService()
    
    private init() {}
    
    /// Gets the current device thermal state indicating system temperature levels
    /// Returns ProcessInfo.ThermalState values: .nominal, .fair, .serious, .critical
    func getThermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    
    /// Gets current CPU usage percentage across all cores
    /// Returns a value between 0.0 and 100.0 representing CPU utilization
    /// Uses host_processor_info to query kernel for CPU statistics
    func getCPUUsage() -> Double {
        var info: processor_info_array_t? = nil
        var numCpuInfo = mach_msg_type_number_t()
        var numCpus = natural_t()
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        var totalUser: Double = 0
        var totalSystem: Double = 0  
        var totalIdle: Double = 0
        var totalNice: Double = 0
        
        guard let infoPtr = info else {
            return 0.0
        }
        
        for i in 0..<numCpus {
            let cpuInfoPtr = infoPtr.advanced(by: Int(i) * Int(CPU_STATE_MAX))
            totalUser += Double(cpuInfoPtr[Int(CPU_STATE_USER)])
            totalSystem += Double(cpuInfoPtr[Int(CPU_STATE_SYSTEM)])
            totalIdle += Double(cpuInfoPtr[Int(CPU_STATE_IDLE)])
            totalNice += Double(cpuInfoPtr[Int(CPU_STATE_NICE)])
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoPtr), vm_size_t(numCpuInfo))
        
        let totalTicks = totalUser + totalSystem + totalIdle + totalNice
        let totalUsed = totalUser + totalSystem + totalNice
        
        return totalTicks > 0 ? (totalUsed / totalTicks) * 100.0 : 0.0
    }
    
    /// Gets current memory usage information including used, total, and percentage
    /// Returns tuple with bytes used, total bytes available, and usage percentage
    /// Uses vm_statistics64 to query kernel memory statistics
    func getMemoryUsage() -> (used: UInt64, total: UInt64, percentage: Double) {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = host_statistics64(mach_host_self(),
                                     HOST_VM_INFO64,
                                     UnsafeMutableRawPointer(&info).assumingMemoryBound(to: integer_t.self),
                                     &count)
        
        guard result == KERN_SUCCESS else {
            return (used: 0, total: 0, percentage: 0.0)
        }
        
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_kernel_page_size)
        
        let usedPages = info.internal_page_count + info.wire_count
        let usedMemory = UInt64(usedPages) * pageSize
        
        let percentage = Double(usedMemory) / Double(totalMemory) * 100.0
        
        return (used: usedMemory, total: totalMemory, percentage: percentage)
    }
    
    /// Gets available storage space information for the device
    /// Returns tuple with free bytes and total bytes for the main storage volume
    /// Uses FileManager to query file system attributes
    func getStorageInfo() -> (free: UInt64, total: UInt64) {
        guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
            return (free: 0, total: 0)
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            return (free: freeSpace, total: totalSpace)
        } catch {
            return (free: 0, total: 0)
        }
    }
    
    /// Gets current battery level and charging state information
    /// Returns tuple with battery level (0.0-1.0) and charging state
    /// Enables battery monitoring if not already enabled
    func getBatteryInfo() -> (level: Float, state: UIDevice.BatteryState) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        return (level: level, state: state)
    }
    
    /// Gets storage info as user properties (static device characteristics)
    /// Returns dictionary with storage metrics suitable for user identification
    func getStorageUserProperties() -> [String: Any] {
        let storageInfo = getStorageInfo()
        return [
            "storage_free_gb": round(Double(storageInfo.free) / (1024 * 1024 * 1024) * 100) / 100,
            "storage_total_gb": round(Double(storageInfo.total) / (1024 * 1024 * 1024) * 100) / 100
        ]
    }
    
    /// Collects all system performance metrics as a dictionary for analytics
    /// Returns comprehensive performance snapshot suitable for event tracking
    func getAllMetrics() -> [String: Any] {
        let thermalState = getThermalState()
        let cpuUsage = getCPUUsage()
        let memoryInfo = getMemoryUsage()
        let batteryInfo = getBatteryInfo()
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        var thermalRating: Int
        switch thermalState {
        case .nominal: thermalRating = 0
        case .fair: thermalRating = 1
        case .serious: thermalRating = 2
        case .critical: thermalRating = 3
        @unknown default: thermalRating = 0
        }
        
        var batteryStateString: String
        switch batteryInfo.state {
        case .unknown: batteryStateString = "unknown"
        case .unplugged: batteryStateString = "unplugged"
        case .charging: batteryStateString = "charging"
        case .full: batteryStateString = "full"
        @unknown default: batteryStateString = "unknown"
        }
        
        return [
            "thermal_state": thermalRating,
            "cpu_usage_percent": round(cpuUsage * 100) / 100,
            "memory_usage_percent": round(memoryInfo.percentage * 100) / 100,
            "memory_used_mb": Int(memoryInfo.used / (1024 * 1024)),
            "memory_total_mb": Int(memoryInfo.total / (1024 * 1024)),
            "battery_level": round(Double(batteryInfo.level) * 100) / 100,
            "battery_state": batteryStateString,
            "is_low_power_mode": isLowPowerMode,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        ]
    }
}
