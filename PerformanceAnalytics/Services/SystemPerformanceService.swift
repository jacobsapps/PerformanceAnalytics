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
    
    /// Gets current CPU usage percentage for the current app's threads
    /// Returns a value between 0.0 and 100.0 representing CPU utilization
    /// Uses thread-specific CPU usage tracking for accurate app performance metrics
    func getCPUUsage() -> Double {
        var totalUsageOfCPU = 0.0
        var threadsList = UnsafeMutablePointer(mutating: [thread_act_t]())
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS {
            for index in 0 ..< threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)))
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        let cpuPercentage = totalUsageOfCPU * 100.0
        print("=== CPU usage: ", String(format: "%.2f%%", cpuPercentage))
        return cpuPercentage
    }
    
    /// Gets current memory usage information for the app's memory footprint
    /// Returns tuple with bytes used, total bytes available, and usage in MB
    /// Uses task_vm_info to get accurate app-specific memory usage
    func getMemoryUsage() -> (used: UInt64, total: UInt64, usedMB: Double) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size)
        let result: kern_return_t = withUnsafeMutablePointer(
            to: &taskInfo
        ) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(TASK_VM_INFO),
                          $0,
                          &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (used: 0, total: 0, usedMB: 0.0)
        }
        
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = UInt64(taskInfo.phys_footprint)
        let usedMB = Double(usedMemory) / (1024 * 1024)
        
        print("=== memory usage: ", String(format: "%.2f MB", usedMB))
        
        return (used: usedMemory, total: totalMemory, usedMB: usedMB)
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
        
        print("UsedMB")
        print(round(memoryInfo.usedMB * 100) / 100)
        return [
            "thermal_state": thermalRating,
            "cpu_usage_percent": round(cpuUsage * 100) / 100,
            "memory_usage_mb": round(memoryInfo.usedMB * 100) / 100,
            "memory_total_mb": Int(memoryInfo.total / (1024 * 1024)),
            "battery_level": round(Double(batteryInfo.level) * 100) / 100,
            "battery_state": batteryStateString,
            "is_low_power_mode": isLowPowerMode,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        ]
    }
}
