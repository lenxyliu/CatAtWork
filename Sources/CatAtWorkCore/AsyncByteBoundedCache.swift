import Foundation

public struct CacheLoadResult<Value: Sendable>: Sendable {
    public let value: Value
    public let cost: Int

    public init(value: Value, cost: Int) {
        self.value = value
        self.cost = max(0, cost)
    }
}

public struct AsyncCacheStatistics: Equatable, Sendable {
    public let hits: Int
    public let misses: Int
    public let coalescedRequests: Int
    public let evictions: Int
    public let retainedItemCount: Int
    public let retainedBytes: Int
    public let inFlightCount: Int
}

/// An actor-isolated LRU for resources whose decoded size is more meaningful
/// than their compressed source size.
///
/// One cancelled waiter never cancels a shared load. `removeAll()` is the
/// namespace/session boundary: it cancels every in-flight task and rejects a
/// late result even when the loader itself cannot stop immediately.
public actor AsyncByteBoundedCache<Key: Hashable & Sendable, Value: Sendable> {
    public typealias Loader = @Sendable () async throws -> CacheLoadResult<Value>

    private struct Entry: Sendable {
        let value: Value
        let cost: Int
        var lastAccess: UInt64
    }

    private struct InFlight: Sendable {
        let token: UInt64
        let epoch: UInt64
        let task: Task<CacheLoadResult<Value>, Error>
    }

    public let byteLimit: Int
    private var entries: [Key: Entry] = [:]
    private var inFlight: [Key: InFlight] = [:]
    private var retainedBytes = 0
    private var clock: UInt64 = 0
    private var nextToken: UInt64 = 0
    private var epoch: UInt64 = 0
    private var hits = 0
    private var misses = 0
    private var coalescedRequests = 0
    private var evictions = 0

    public init(byteLimit: Int) {
        self.byteLimit = max(0, byteLimit)
    }

    public func value(for key: Key, loader: @escaping Loader) async throws -> Value {
        if var entry = entries[key] {
            hits += 1
            clock &+= 1
            entry.lastAccess = clock
            entries[key] = entry
            return entry.value
        }

        let request: InFlight
        if let existing = inFlight[key] {
            coalescedRequests += 1
            request = existing
        } else {
            misses += 1
            nextToken &+= 1
            let task = Task { try await loader() }
            request = InFlight(token: nextToken, epoch: epoch, task: task)
            inFlight[key] = request
        }

        let loaded: CacheLoadResult<Value>
        do {
            loaded = try await request.task.value
        } catch {
            if inFlight[key]?.token == request.token {
                inFlight[key] = nil
            }
            throw error
        }
        guard request.epoch == epoch else { throw CancellationError() }
        if inFlight[key]?.token == request.token {
            inFlight[key] = nil
            insert(loaded, for: key)
        }
        try Task.checkCancellation()
        // Another waiter may have finalized and immediately evicted an
        // oversized value. Every waiter from this still-valid epoch may
        // nevertheless consume the one coalesced result.
        return entries[key]?.value ?? loaded.value
    }

    public func removeAll() {
        epoch &+= 1
        entries.removeAll(keepingCapacity: false)
        retainedBytes = 0
        for request in inFlight.values {
            request.task.cancel()
        }
        inFlight.removeAll(keepingCapacity: false)
    }

    public func statistics() -> AsyncCacheStatistics {
        AsyncCacheStatistics(
            hits: hits,
            misses: misses,
            coalescedRequests: coalescedRequests,
            evictions: evictions,
            retainedItemCount: entries.count,
            retainedBytes: retainedBytes,
            inFlightCount: inFlight.count
        )
    }

    private func insert(_ loaded: CacheLoadResult<Value>, for key: Key) {
        guard byteLimit > 0, loaded.cost <= byteLimit else { return }
        if let prior = entries.removeValue(forKey: key) {
            retainedBytes -= prior.cost
        }
        while retainedBytes + loaded.cost > byteLimit,
              let victim = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key,
              let removed = entries.removeValue(forKey: victim) {
            retainedBytes -= removed.cost
            evictions += 1
        }
        clock &+= 1
        entries[key] = Entry(value: loaded.value, cost: loaded.cost, lastAccess: clock)
        retainedBytes += loaded.cost
    }
}
