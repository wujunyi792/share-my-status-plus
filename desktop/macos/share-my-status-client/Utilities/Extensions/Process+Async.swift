//
//  Process+Async.swift
//  share-my-status-client
//


import Foundation

extension Process {
    /// Run process asynchronously and return output
    static func runAsync(
        launchPath: String,
        arguments: [String],
        timeout: TimeInterval = 30
    ) async throws -> (output: Data, exitCode: Int32) {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.launchPath = launchPath
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var isFinished = false
            var outputData = Data()
            
            process.terminationHandler = { process in
                isFinished = true
                let exitCode = process.terminationStatus
                continuation.resume(returning: (outputData, exitCode))
            }
            
            // Start reading output
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                }
            }
            
            do {
                try process.run()
                
                // Setup timeout
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if !isFinished {
                        process.terminate()
                        continuation.resume(throwing: ProcessError.timeout)
                    }
                }
            } catch {
                continuation.resume(throwing: ProcessError.launchFailed(error))
            }
        }
    }
    
    /// Run process and get real-time output stream
    static func streamOutput(
        launchPath: String,
        arguments: [String],
        onOutput: @escaping (Data) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) throws {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        process.terminationHandler = { process in
            onCompletion(process.terminationStatus)
        }
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                onOutput(data)
            }
        }
        
        try process.run()
    }
}

enum ProcessError: LocalizedError {
    case timeout
    case launchFailed(Error)
    case nonZeroExit(Int32)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Process timed out"
        case .launchFailed(let error):
            return "Failed to launch process: \(error.localizedDescription)"
        case .nonZeroExit(let code):
            return "Process exited with code \(code)"
        }
    }
}

