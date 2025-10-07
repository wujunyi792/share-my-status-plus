//
//  SystemMonitorService.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import IOKit
import IOKit.ps

/// Actor-based system monitoring service for thread-safe system metrics collection
actor SystemMonitorService: PollingMonitoringService {
    // MARK: - PollingMonitoringService Conformance
    let monitoringType: MonitoringType = .polling
    
    private(set) var pollingInterval: TimeInterval = 10.0
    
    func isActive() -> Bool {
        return isMonitoring
    }
    
    func start() async throws {
        await startMonitoring(interval: pollingInterval)
    }
    
    func stop() async {
        stopMonitoring()
    }
    
    func updatePollingInterval(_ interval: TimeInterval) async {
        let wasMonitoring = isMonitoring
        
        // Stop current monitoring
        if wasMonitoring {
            stopMonitoring()
        }
        
        // Update interval
        pollingInterval = interval
        logger.info("Polling interval updated to \(interval)s")
        
        // Restart if it was running
        if wasMonitoring {
            await startMonitoring(interval: interval)
        }
    }
    
    // MARK: - Properties
    private let logger = AppLogger.system
    private var currentSnapshot: SystemSnapshot?
    private var isMonitoring = false
    private var monitorTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    deinit {
        monitorTask?.cancel()
    }
    
    // MARK: - Monitoring Control
    private func startMonitoring(interval: TimeInterval) async {
        guard !isMonitoring else {
            logger.warning("Already monitoring")
            return
        }
        
        logger.info("Starting system monitoring with interval \(interval)s...")
        isMonitoring = true
        pollingInterval = interval
        
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.collectMetrics()
                if let interval = await self?.pollingInterval {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    private func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping system monitoring...")
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
        currentSnapshot = nil
    }
    
    // MARK: - Get Current State
    func getCurrentSnapshot() -> SystemSnapshot? {
        return currentSnapshot
    }
    
    func getIsMonitoring() -> Bool {
        return isMonitoring
    }
    
    // MARK: - Collect Metrics
    func collectMetrics() async {
        let batteryInfo = getBatteryInfo()
        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryUsage()
        
        let snapshot = SystemSnapshot(
            batteryLevel: batteryInfo.level,
            isCharging: batteryInfo.isCharging,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            timestamp: Date()
        )
        
        currentSnapshot = snapshot
        logger.debug("System metrics collected: CPU=\(cpuUsage ?? 0), Memory=\(memoryUsage ?? 0)")
    }
    
    // MARK: - Battery Info
    private func getBatteryInfo() -> (level: Double?, isCharging: Bool?) {
        let powerSources = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSources)?.takeRetainedValue() as? [CFTypeRef] else {
            return (nil, nil)
        }
        
        for powerSource in powerSourcesList {
            guard let powerSourceInfo = IOPSGetPowerSourceDescription(powerSources, powerSource)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check if it's internal battery
            if let type = powerSourceInfo[kIOPSTypeKey] as? String,
               type == kIOPSInternalBatteryType {
                
                let capacity = powerSourceInfo[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCapacity = powerSourceInfo[kIOPSMaxCapacityKey] as? Int ?? 100
                let isCharging = powerSourceInfo[kIOPSIsChargingKey] as? Bool ?? false
                
                let batteryLevel = maxCapacity > 0 ? Double(capacity) / Double(maxCapacity) : nil
                
                return (batteryLevel, isCharging)
            }
        }
        
        return (nil, nil)
    }
    
    // MARK: - CPU Usage
    private func getCPUUsage() -> Double? {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS else { return nil }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
        }
        
        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        var totalNice: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(CPU_STATE_MAX) * i)
            totalUser += UInt32(cpuLoadInfo[Int(CPU_STATE_USER)])
            totalSystem += UInt32(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt32(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            totalNice += UInt32(cpuLoadInfo[Int(CPU_STATE_NICE)])
        }
        
        let totalTicks = totalUser + totalSystem + totalIdle + totalNice
        let usedTicks = totalUser + totalSystem + totalNice
        
        return totalTicks > 0 ? Double(usedTicks) / Double(totalTicks) : nil
    }
    
    // MARK: - Memory Usage
    private func getMemoryUsage() -> Double? {
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let totalPages = vmStats.free_count + vmStats.active_count + vmStats.inactive_count + vmStats.wire_count
        let usedPages = vmStats.active_count + vmStats.inactive_count + vmStats.wire_count
        
        return totalPages > 0 ? Double(usedPages) / Double(totalPages) : nil
    }
}

