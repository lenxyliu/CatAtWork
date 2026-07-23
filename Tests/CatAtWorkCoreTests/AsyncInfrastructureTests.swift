import Foundation
import XCTest
@testable import CatAtWorkCore

private actor AsyncLoadCounter {
    private(set) var count = 0

    func load(_ value: String, cost: Int, delay: Duration = .zero) async throws -> CacheLoadResult<String> {
        count += 1
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return CacheLoadResult(value: value, cost: cost)
    }
}

private actor NonCancellingGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

final class AsyncInfrastructureTests: XCTestCase {
    @MainActor
    func testBackgroundIORunsAwayFromMainThread() async throws {
        let ranOnMainThread = try await BackgroundIO.run {
            Thread.isMainThread
        }
        XCTAssertFalse(ranOnMainThread)
    }

    func testCacheHitsAndCoalescesConcurrentLoads() async throws {
        let cache = AsyncByteBoundedCache<String, String>(byteLimit: 100)
        let counter = AsyncLoadCounter()

        async let first = cache.value(for: "frame") {
            try await counter.load("decoded", cost: 40, delay: .milliseconds(50))
        }
        async let second = cache.value(for: "frame") {
            try await counter.load("should-not-run", cost: 40)
        }
        let concurrentValues = try await [first, second]
        XCTAssertEqual(concurrentValues[0], concurrentValues[1])
        let winningValue = concurrentValues[0]
        let cachedValue = try await cache.value(for: "frame") {
            try await counter.load("should-not-run", cost: 40)
        }
        XCTAssertEqual(cachedValue, winningValue)

        let stats = await cache.statistics()
        let loadCount = await counter.count
        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.coalescedRequests, 1)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.retainedItemCount, 1)
        XCTAssertEqual(stats.retainedBytes, 40)
    }

    func testCacheEvictsLeastRecentlyUsedWithinByteLimit() async throws {
        let cache = AsyncByteBoundedCache<String, String>(byteLimit: 8)
        _ = try await cache.value(for: "a") { CacheLoadResult(value: "A", cost: 4) }
        _ = try await cache.value(for: "b") { CacheLoadResult(value: "B", cost: 4) }
        _ = try await cache.value(for: "a") { CacheLoadResult(value: "unused", cost: 4) }
        _ = try await cache.value(for: "c") { CacheLoadResult(value: "C", cost: 4) }

        let counter = AsyncLoadCounter()
        let reloadedValue = try await cache.value(for: "b") {
            try await counter.load("B2", cost: 4)
        }
        let stats = await cache.statistics()
        let reloadCount = await counter.count
        XCTAssertEqual(reloadedValue, "B2")
        XCTAssertEqual(reloadCount, 1)
        XCTAssertEqual(stats.retainedBytes, 8)
        XCTAssertEqual(stats.retainedItemCount, 2)
        XCTAssertEqual(stats.evictions, 2)
    }

    func testCacheInvalidationCancelsInFlightLoadAndRejectsLateResult() async throws {
        let cache = AsyncByteBoundedCache<String, String>(byteLimit: 100)
        let gate = NonCancellingGate()
        let request = Task {
            try await cache.value(for: "old-session") {
                await gate.wait()
                return CacheLoadResult(value: "stale", cost: 10)
            }
        }
        while await cache.statistics().inFlightCount == 0 {
            await Task.yield()
        }
        await cache.removeAll()
        await gate.open()

        do {
            _ = try await request.value
            XCTFail("Invalidated load must not publish")
        } catch is CancellationError {
            // Expected.
        }
        let stats = await cache.statistics()
        XCTAssertEqual(stats.inFlightCount, 0)
        XCTAssertEqual(stats.retainedItemCount, 0)
        XCTAssertEqual(stats.retainedBytes, 0)
    }

    func testProcessRunnerDrainsPipeWhileBoundingCapturedDiagnostics() async throws {
        let result = try await AsyncProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import sys; sys.stdout.buffer.write(b'x'*2000000); sys.stderr.buffer.write(b'y'*2000000)",
            ],
            timeout: .seconds(10),
            maximumCapturedOutputBytes: 32 * 1_024
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.output.count, 32 * 1_024)
        XCTAssertTrue(result.outputWasTruncated)
    }

    func testProcessRunnerEnforcesTimeout() async {
        do {
            _ = try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["5"],
                timeout: .milliseconds(50),
                maximumCapturedOutputBytes: 1_024
            )
            XCTFail("Timed-out helper must not succeed")
        } catch {
            XCTAssertEqual(error as? ProcessRunError, .timedOut)
        }
    }

    func testProcessRunnerPropagatesCancellation() async {
        let request = Task {
            try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["5"],
                timeout: .seconds(10),
                maximumCapturedOutputBytes: 1_024
            )
        }
        try? await Task.sleep(for: .milliseconds(50))
        request.cancel()

        do {
            _ = try await request.value
            XCTFail("Cancelled helper must not succeed")
        } catch {
            XCTAssertEqual(error as? ProcessRunError, .cancelled)
        }
    }
}
