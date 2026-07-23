import Foundation
import Darwin

public struct ProcessRunResult: Equatable, Sendable {
    public let terminationStatus: Int32
    public let output: Data
    public let outputWasTruncated: Bool

    public init(terminationStatus: Int32, output: Data, outputWasTruncated: Bool) {
        self.terminationStatus = terminationStatus
        self.output = output
        self.outputWasTruncated = outputWasTruncated
    }
}

public enum ProcessRunError: Error, Equatable {
    case timedOut
    case cancelled
}

/// Executes a data-only helper without allowing stdout/stderr to fill an
/// unread pipe. Both streams share one pipe, which is drained before waiting
/// for termination; retained diagnostics are independently byte-bounded.
public enum AsyncProcessRunner {
    public static func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration,
        maximumCapturedOutputBytes: Int
    ) async throws -> ProcessRunResult {
        let control = ProcessControl()
        let work = Task.detached(priority: .userInitiated) {
            try control.run(
                executableURL: executableURL,
                arguments: arguments,
                timeout: timeout,
                maximumCapturedOutputBytes: max(0, maximumCapturedOutputBytes)
            )
        }
        return try await withTaskCancellationHandler {
            do {
                return try await work.value
            } catch is CancellationError {
                throw ProcessRunError.cancelled
            }
        } onCancel: {
            control.cancel()
            work.cancel()
        }
    }
}

private final class ProcessControl: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancellationRequested = false
    private var timeoutReached = false

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration,
        maximumCapturedOutputBytes: Int
    ) throws -> ProcessRunResult {
        try Task.checkCancellation()
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output

        lock.lock()
        if cancellationRequested {
            lock.unlock()
            throw ProcessRunError.cancelled
        }
        self.process = process
        lock.unlock()

        try process.run()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        let timeoutSeconds = max(0, Double(timeout.components.seconds)
            + Double(timeout.components.attoseconds) / 1_000_000_000_000_000_000)
        timer.schedule(deadline: .now() + timeoutSeconds)
        timer.setEventHandler { [weak self] in self?.timeout() }
        timer.resume()

        var captured = Data()
        var truncated = false
        let reader = output.fileHandleForReading
        while let chunk = try reader.read(upToCount: 64 * 1_024), !chunk.isEmpty {
            let remaining = maximumCapturedOutputBytes - captured.count
            if remaining > 0 {
                captured.append(chunk.prefix(remaining))
            }
            if chunk.count > max(0, remaining) {
                truncated = true
            }
        }
        process.waitUntilExit()
        timer.cancel()
        clearProcess()

        lock.lock()
        let wasCancelled = cancellationRequested
        let didTimeOut = timeoutReached
        lock.unlock()
        if didTimeOut { throw ProcessRunError.timedOut }
        if wasCancelled || Task.isCancelled { throw ProcessRunError.cancelled }
        return ProcessRunResult(
            terminationStatus: process.terminationStatus,
            output: captured,
            outputWasTruncated: truncated
        )
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let running = process
        lock.unlock()
        if let running, running.isRunning {
            running.terminate()
            forceKillIfStillRunning(running)
        }
    }

    private func timeout() {
        lock.lock()
        timeoutReached = true
        let running = process
        lock.unlock()
        if let running, running.isRunning {
            running.terminate()
            forceKillIfStillRunning(running)
        }
    }

    private func forceKillIfStillRunning(_ process: Process) {
        let processID = process.processIdentifier
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.forceKillIfCurrent(processID)
        }
    }

    private func forceKillIfCurrent(_ processID: Int32) {
        lock.lock()
        let shouldKill = process?.processIdentifier == processID && process?.isRunning == true
        lock.unlock()
        if shouldKill {
            Darwin.kill(processID, SIGKILL)
        }
    }

    private func clearProcess() {
        lock.lock()
        process = nil
        lock.unlock()
    }
}
