import CatAtWorkCore
import Foundation
import MetalKit

struct MetalTextureCacheKey: Hashable, Sendable {
    let sessionGeneration: UInt64
    let canonicalPath: String
}

final class MetalTextureResource: @unchecked Sendable {
    let texture: any MTLTexture
    let decodedByteCost: Int

    init(texture: any MTLTexture) {
        self.texture = texture
        let (pixels, pixelOverflow) = texture.width.multipliedReportingOverflow(by: texture.height)
        let (rgbaBytes, byteOverflow) = pixels.multipliedReportingOverflow(by: 4)
        let estimatedRGBABytes = pixelOverflow || byteOverflow ? Int.max : rgbaBytes
        decodedByteCost = max(texture.allocatedSize, estimatedRGBABytes)
    }
}

private final class MetalDeviceBox: @unchecked Sendable {
    let device: any MTLDevice

    init(_ device: any MTLDevice) {
        self.device = device
    }
}

actor MetalTextureCache {
    static let defaultByteLimit = 128 * 1_024 * 1_024

    private let device: MetalDeviceBox
    private let storage: AsyncByteBoundedCache<MetalTextureCacheKey, MetalTextureResource>
    private var activeGeneration: UInt64

    init(
        device: any MTLDevice,
        byteLimit: Int = MetalTextureCache.defaultByteLimit,
        initialGeneration: UInt64 = 0
    ) {
        self.device = MetalDeviceBox(device)
        storage = AsyncByteBoundedCache(byteLimit: byteLimit)
        activeGeneration = initialGeneration
    }

    func beginSession(generation: UInt64) async {
        activeGeneration = generation
        await storage.removeAll()
    }

    func texture(at url: URL, sessionGeneration: UInt64) async throws -> MetalTextureResource {
        guard sessionGeneration == activeGeneration else { throw CancellationError() }
        let key = MetalTextureCacheKey(
            sessionGeneration: sessionGeneration,
            canonicalPath: url.resolvingSymlinksInPath().standardizedFileURL.path
        )
        let device = device
        let resource = try await storage.value(for: key) {
            try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let loader = MTKTextureLoader(device: device.device)
                let texture = try loader.newTexture(URL: url, options: [
                    .SRGB: true,
                    .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                    .origin: MTKTextureLoader.Origin.topLeft.rawValue,
                ])
                let resource = MetalTextureResource(texture: texture)
                return CacheLoadResult(
                    value: resource,
                    cost: resource.decodedByteCost
                )
            }.value
        }
        guard sessionGeneration == activeGeneration else { throw CancellationError() }
        return resource
    }

    func statistics() async -> AsyncCacheStatistics {
        await storage.statistics()
    }
}
