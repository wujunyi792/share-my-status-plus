//
//  SystemMonitorService.swift
//  share-my-status-client
//


import Foundation
import IOKit
import IOKit.ps

/// Actor-based system monitoring service for thread-safe system metrics collection
actor SystemMonitorService: PollingMonitoringService {
    // PollingMonitoringService Conformance
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
    
    // Properties
    private let logger = AppLogger.system
    private var currentSnapshot: SystemSnapshot?
    private var isMonitoring = false
    private var monitorTask: Task<Void, Never>?
    
    // Previous CPU tick values for differential calculation
    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    
    // Reusable host port to avoid mach port leaks
    private let hostPort: mach_port_t = mach_host_self()
    
    // Lifecycle
    deinit {
        monitorTask?.cancel()
        mach_port_deallocate(mach_task_self_, hostPort)
    }
    
    // Monitoring Control
    private func startMonitoring(interval: TimeInterval) async {
        guard !isMonitoring else {
            logger.warning("Already monitoring")
            return
        }
        
        logger.info("Starting system monitoring with interval \(interval)s...")
        isMonitoring = true
        pollingInterval = interval
        previousCPUTicks = nil
        
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
        previousCPUTicks = nil
    }
    
    // Get Current State
    func getCurrentSnapshot() -> SystemSnapshot? {
        return currentSnapshot
    }
    
    func getIsMonitoring() -> Bool {
        return isMonitoring
    }
    
    // Collect Metrics
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
    
    // Battery Info
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
    
    // CPU Usage (differential - measures current interval, not since boot)
    private func getCPUUsage() -> Double? {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS else { return nil }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
        }
        
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        
        for i in 0..<Int(numCpus) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(CPU_STATE_MAX) * i)
            totalUser += UInt64(cpuLoadInfo[Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            totalNice += UInt64(cpuLoadInfo[Int(CPU_STATE_NICE)])
        }
        
        let currentTicks = (user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)
        
        defer { previousCPUTicks = currentTicks }
        
        guard let prev = previousCPUTicks else {
            // First sample — return nil (need two samples for differential)
            return nil
        }
        
        let deltaUser   = totalUser   - prev.user
        let deltaSystem = totalSystem - prev.system
        let deltaIdle   = totalIdle   - prev.idle
        let deltaNice   = totalNice   - prev.nice
        
        let deltaTotal = deltaUser + deltaSystem + deltaIdle + deltaNice
        let deltaUsed  = deltaUser + deltaSystem + deltaNice
        
        return deltaTotal > 0 ? Double(deltaUsed) / Double(deltaTotal) : nil
    }
    
    // Memory Usage
    private func getMemoryUsage() -> Double? {
        // Get physical memory size
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0) == 0 else {
            return nil
        }
        let totalPhysicalMemory = Double(size)
        
        // Get VM statistics
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let port = hostPort
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(port, HOST_VM_INFO64, $0, &infoCount)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        // Get page size
        let pageSize = UInt64(vm_kernel_page_size)
        
        // Used memory: wired + active + inactive + compressed - purgeable
        let wiredPages = vmStats.wire_count
        let activePages = vmStats.active_count
        let inactivePages = vmStats.inactive_count
        let compressedPages = vmStats.compressor_page_count
        let purgeablePages = vmStats.purgeable_count
        
        let usedPages = wiredPages + activePages + inactivePages + compressedPages - purgeablePages
        let usedMemory = Double(usedPages) * Double(pageSize)
        
        let memoryUsage = usedMemory / totalPhysicalMemory
        
        return max(0.0, min(1.0, memoryUsage))
    }
}

