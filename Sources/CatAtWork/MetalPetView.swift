import AppKit
import CatAtWorkCore
import MetalKit

@MainActor
final class MetalPetView: MTKView, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let textureCache: MetalTextureCache
    private var pipeline: MTLRenderPipelineState!
    private var texture: MTLTexture?
    private var textureLoadTask: Task<Void, Never>?
    private var sessionPreparationTask: Task<Void, Never>?
    private var lastFrameURL: URL?
    private var atlasRect: PixelRect?
    private var positionRect = SIMD4<Float>(-1, -1, 1, 1)
    private var flipHorizontally = false
    private var eyeOffsetPixels = SIMD2<Float>(repeating: 0)
    private var sessionGeneration: UInt64 = 0
    var onRightMouseDown: ((NSEvent) -> Void)?

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func rightMouseDown(with event: NSEvent) {
        onRightMouseDown?(event)
    }

    var frameURL: URL? {
        didSet {
            guard frameURL != lastFrameURL else { return }
            lastFrameURL = frameURL
            requestTexture()
        }
    }

    func displayFrame(
        url: URL,
        textureRect: PixelRect?,
        sourceSize: PixelSize,
        pivot: NormalizedPoint,
        renderOffset: PixelPoint?,
        canvasLayout: PetCanvasLayout,
        bodyScale: Double,
        flipHorizontally: Bool = false,
        eyeOffsetPixels: SIMD2<Float> = .zero
    ) {
        self.flipHorizontally = flipHorizontally
        self.eyeOffsetPixels = eyeOffsetPixels
        atlasRect = textureRect
        let canvasWidth = Double(canvasLayout.size.width)
        let canvasHeight = Double(canvasLayout.size.height)
        let spriteWidth = Double(sourceSize.width) * bodyScale
        let spriteHeight = Double(sourceSize.height) * bodyScale
        let anchorX = canvasLayout.anchorFromTop.x
        let anchorYFromTop = canvasLayout.anchorFromTop.y
        let originX = anchorX - pivot.x * spriteWidth + (renderOffset?.x ?? 0) * bodyScale
        let originY = anchorYFromTop - pivot.y * spriteHeight + (renderOffset?.y ?? 0) * bodyScale
        positionRect = SIMD4<Float>(
            Float(originX / canvasWidth * 2 - 1),
            Float(1 - (originY + spriteHeight) / canvasHeight * 2),
            Float((originX + spriteWidth) / canvasWidth * 2 - 1),
            Float(1 - originY / canvasHeight * 2)
        )
        frameURL = url
        setNeedsDisplay(bounds)
    }

    func resetSession(generation: UInt64) {
        textureLoadTask?.cancel()
        sessionGeneration = generation
        frameURL = nil
        lastFrameURL = nil
        texture = nil
        atlasRect = nil
        positionRect = SIMD4<Float>(-1, -1, 1, 1)
        flipHorizontally = false
        eyeOffsetPixels = .zero
        let textureCache = textureCache
        sessionPreparationTask = Task {
            await textureCache.beginSession(generation: generation)
        }
        setNeedsDisplay(bounds)
    }

    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            fatalError("Metal is required to run 猫上班了")
        }
        commandQueue = queue
        textureCache = MetalTextureCache(device: device)
        super.init(frame: frame, device: device)
        wantsLayer = true
        framebufferOnly = true
        // The source artwork is authored in sRGB. MTKTextureLoader decodes an
        // sRGB texture to linear values before the fragment shader sees it, so
        // the drawable must also be sRGB. A plain `bgra8Unorm` drawable stores
        // those linear values verbatim and Core Animation then displays them as
        // sRGB, which makes the entire cat (especially the dark face/legs) look
        // much darker than the source PNG and QA previews.
        colorPixelFormat = .bgra8Unorm_srgb
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        configureTransparentLayer()
        enableSetNeedsDisplay = true
        isPaused = true
        delegate = self
        pipeline = Self.makePipeline(device: device, pixelFormat: colorPixelFormat)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparentLayer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipeline)
        if let texture {
            let rect = atlasRect ?? PixelRect(x: 0, y: 0, width: texture.width, height: texture.height)
            var uvRect = SIMD4<Float>(
                Float(rect.x) / Float(texture.width), Float(rect.y) / Float(texture.height),
                Float(rect.x + rect.width) / Float(texture.width), Float(rect.y + rect.height) / Float(texture.height)
            )
            if flipHorizontally {
                let left = uvRect.x
                uvRect.x = uvRect.z
                uvRect.z = left
            }
            encoder.setVertexBytes(&uvRect, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setVertexBytes(&positionRect, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            var eyeUVOffset = SIMD2<Float>(
                eyeOffsetPixels.x / Float(texture.width),
                -eyeOffsetPixels.y / Float(texture.height)
            )
            encoder.setFragmentBytes(&eyeUVOffset, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func requestTexture() {
        textureLoadTask?.cancel()
        guard let frameURL else { texture = nil; setNeedsDisplay(bounds); return }
        texture = nil
        let generation = sessionGeneration
        let preparation = sessionPreparationTask
        let textureCache = textureCache
        textureLoadTask = Task { [weak self] in
            await preparation?.value
            guard !Task.isCancelled else { return }
            do {
                let resource = try await textureCache.texture(
                    at: frameURL,
                    sessionGeneration: generation
                )
                try Task.checkCancellation()
                guard let self,
                      self.sessionGeneration == generation,
                      self.frameURL == frameURL else { return }
                self.texture = resource.texture
                self.setNeedsDisplay(self.bounds)
            } catch {
                // Cancellation, invalidation and decode failure all leave the
                // view transparent; a late result is never published.
            }
        }
    }

    private func configureTransparentLayer() {
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        if let metalLayer = layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.backgroundColor = NSColor.clear.cgColor
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        }
    }

    private static func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct Out { float4 position [[position]]; float2 uv; };
        vertex Out petVertex(uint id [[vertex_id]], constant float4 &uvRect [[buffer(0)]],
                             constant float4 &positionRect [[buffer(1)]]) {
            const float2 cornersPosition[4] = { {0,0}, {1,0}, {0,1}, {1,1} };
            const float2 corners[4] = { {0,1}, {1,1}, {0,0}, {1,0} };
            float2 uvMin = uvRect.xy; float2 uvMax = uvRect.zw;
            float2 positionMin = positionRect.xy; float2 positionMax = positionRect.zw;
            Out out; out.position = float4(mix(positionMin, positionMax, cornersPosition[id]), 0, 1);
            out.uv = mix(uvMin, uvMax, corners[id]); return out;
        }
        float eyeMask(float4 color) {
            float blueVsRed = smoothstep(0.055, 0.16, color.b - color.r);
            float blueVsGreen = smoothstep(0.025, 0.11, color.b - color.g);
            float brightness = smoothstep(0.28, 0.52, color.b);
            return blueVsRed * blueVsGreen * brightness * color.a;
        }
        fragment float4 petFragment(Out in [[stage_in]], texture2d<float> image [[texture(0)]],
                                    constant float2 &eyeOffset [[buffer(0)]]) {
            constexpr sampler s(address::clamp_to_edge, filter::linear);
            float4 base = image.sample(s, in.uv);
            if (all(abs(eyeOffset) < float2(0.000001))) { return base; }

            // The cat's blue-gray irises are the only blue pixels in the sprite.
            // Remove them at their old position and re-sample them a few source
            // pixels away. Body/fur pixels are never warped, so gaze cannot make
            // the whole head or pose jump between direction sheets.
            float oldEye = eyeMask(base);
            float4 shifted = image.sample(s, in.uv - eyeOffset);
            float shiftedEye = eyeMask(shifted);
            float3 socket = base.rgb * float3(0.18, 0.22, 0.28);
            float4 result = float4(mix(base.rgb, socket, oldEye), base.a);
            result.rgb = mix(result.rgb, shifted.rgb, shiftedEye);
            result.a = max(result.a, shifted.a * shiftedEye);
            return result;
        }
        """
        let library = try! device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "petVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "petFragment")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        // PNGs are loaded with straight alpha. Premultiply while blending into the transparent
        // drawable so low-alpha chroma pixels cannot become a bright/green fur halo.
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }
}
