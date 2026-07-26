import Foundation

public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct NormalizedPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PixelRect: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PetFrame: Codable, Hashable, Sendable {
    public var image: String
    public var sourceSize: PixelSize
    public var trimRect: PixelRect
    /// Rectangle of this frame inside `image` when the resource is a variable-rectangle atlas.
    /// Nil means the whole image is the frame (legacy compatibility).
    public var textureRect: PixelRect?
    public var collisionRect: PixelRect?
    public var pivot: NormalizedPoint
    /// Per-frame authoring displacement from the shared world anchor, in source pixels.
    /// Positive x moves right; positive y moves down in image coordinates. This is used
    /// for real spatial motion such as a jump arc without changing the cat's body scale.
    public var renderOffset: PixelPoint?
    public var duration: Double
    /// Authoring-time identity calibration. It restores canonical body scale; it is never a fit-to-cell value.
    public var bodyScale: Double?
    /// Format-2 anatomical root in fixed authored-canvas pixels.
    public var rootAnchor: PixelPoint?
    /// Format-2 named support/contact points in fixed authored-canvas pixels.
    public var supportAnchors: [PetSupportAnchor]?
    /// Format-2 canonical straight-RGBA source digest.
    public var sourcePixelSHA256: String?
    /// Format-2 digest of the exact atlas rectangle. It must equal the source digest.
    public var atlasPixelSHA256: String?
    /// The one reviewed exception authorizing a material secondary component.
    public var componentExceptionReviewId: String?

    public init(
        image: String,
        sourceSize: PixelSize,
        trimRect: PixelRect,
        textureRect: PixelRect? = nil,
        collisionRect: PixelRect? = nil,
        pivot: NormalizedPoint,
        renderOffset: PixelPoint? = nil,
        duration: Double,
        bodyScale: Double? = nil,
        rootAnchor: PixelPoint? = nil,
        supportAnchors: [PetSupportAnchor]? = nil,
        sourcePixelSHA256: String? = nil,
        atlasPixelSHA256: String? = nil,
        componentExceptionReviewId: String? = nil
    ) {
        self.image = image
        self.sourceSize = sourceSize
        self.trimRect = trimRect
        self.textureRect = textureRect
        self.collisionRect = collisionRect
        self.pivot = pivot
        self.renderOffset = renderOffset
        self.duration = duration
        self.bodyScale = bodyScale
        self.rootAnchor = rootAnchor
        self.supportAnchors = supportAnchors
        self.sourcePixelSHA256 = sourcePixelSHA256
        self.atlasPixelSHA256 = atlasPixelSHA256
        self.componentExceptionReviewId = componentExceptionReviewId
    }
}

public enum LoopMode: String, Codable, Sendable {
    case loop
    case once
    case pingPong
}

public struct PetAnimation: Codable, Hashable, Sendable {
    public var id: String
    public var loopMode: LoopMode
    public var nextAnimation: String?
    public var startPose: String?
    public var endPose: String?
    public var startPoseSignature: PetPoseSignature?
    public var endPoseSignature: PetPoseSignature?
    public var loopStartFrame: Int?
    public var frames: [PetFrame]

    public init(id: String, loopMode: LoopMode, nextAnimation: String? = nil,
                startPose: String? = nil, endPose: String? = nil,
                startPoseSignature: PetPoseSignature? = nil,
                endPoseSignature: PetPoseSignature? = nil,
                loopStartFrame: Int? = nil,
                frames: [PetFrame]) {
        self.id = id
        self.loopMode = loopMode
        self.nextAnimation = nextAnimation
        self.startPose = startPose
        self.endPose = endPose
        self.startPoseSignature = startPoseSignature
        self.endPoseSignature = endPoseSignature
        self.loopStartFrame = loopStartFrame
        self.frames = frames
    }
}

public struct LookDirection: Codable, Hashable, Sendable {
    public var degrees: Double
    public var frame: PetFrame

    public init(degrees: Double, frame: PetFrame) {
        self.degrees = degrees
        self.frame = frame
    }
}

public struct PetManifest: Codable, Hashable, Sendable {
    public var formatVersion: Int
    public var id: String
    public var displayName: String
    public var author: String
    public var description: String
    public var minimumAppVersion: String
    public var assetVersion: String?
    public var pixelsPerBodyUnit: Double
    public var authoredCanvas: AuthoredCanvas?
    public var colorSpace: PetColorContract?
    public var componentPolicy: PetComponentPolicy?
    public var identityRig: CanonicalIdentityRig?
    public var animations: [PetAnimation]
    public var lookDirections: [LookDirection]

    public init(
        formatVersion: Int = 1,
        id: String,
        displayName: String,
        author: String,
        description: String,
        minimumAppVersion: String = "1.0.0",
        assetVersion: String? = nil,
        pixelsPerBodyUnit: Double,
        authoredCanvas: AuthoredCanvas? = nil,
        colorSpace: PetColorContract? = nil,
        componentPolicy: PetComponentPolicy? = nil,
        identityRig: CanonicalIdentityRig? = nil,
        animations: [PetAnimation],
        lookDirections: [LookDirection]
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.displayName = displayName
        self.author = author
        self.description = description
        self.minimumAppVersion = minimumAppVersion
        self.assetVersion = assetVersion
        self.pixelsPerBodyUnit = pixelsPerBodyUnit
        self.authoredCanvas = authoredCanvas
        self.colorSpace = colorSpace
        self.componentPolicy = componentPolicy
        self.identityRig = identityRig
        self.animations = animations
        self.lookDirections = lookDirections
    }
}

public enum PetManifestIssue: Error, Equatable, CustomStringConvertible {
    case unsupportedVersion(Int)
    case invalidIdentifier
    case duplicateAnimation(String)
    case missingIdle
    case missingFrames(String)
    case invalidFramePath(String)
    case invalidFrameGeometry(String)
    case invalidFrameDuration(String)
    case insufficientFrames(animation: String, actual: Int)
    case invalidLookDirections
    case invalidMinimumAppVersion
    case invalidMetadata(String)
    case tooManyAnimations(Int)
    case tooManyFrames(animation: String, actual: Int)
    case invalidNextAnimation(String)
    case invalidPose(animation: String, pose: String)
    case missingCanonicalMetadata(String)
    case invalidCanonicalMetadata(String)
    case invalidAnchor(animation: String, frame: Int)
    case invalidEndpointSignature(String)
    case invalidIdentityRig(String)
    case invalidComponentPolicy(String)

    public var description: String {
        switch self {
        case .unsupportedVersion(let version): "Unsupported .catpet version: \(version)"
        case .invalidIdentifier: "The pet identifier is invalid."
        case .duplicateAnimation(let id): "Duplicate animation: \(id)"
        case .missingIdle: "The pet has no idle animation."
        case .missingFrames(let id): "Animation \(id) has no frames."
        case .invalidFramePath(let path): "Unsafe frame path: \(path)"
        case .invalidFrameGeometry(let id): "Animation \(id) has invalid frame geometry."
        case .invalidFrameDuration(let id): "Animation \(id) has an invalid frame duration."
        case .insufficientFrames(let animation, let actual): "Animation \(animation) has \(actual) frames; 24 are required for a high-frame pet."
        case .invalidLookDirections: "Look directions must contain the 16 fixed 22.5-degree directions."
        case .invalidMinimumAppVersion: "minimumAppVersion must be a numeric dotted version."
        case .invalidMetadata(let field): "Invalid or oversized manifest metadata: \(field)"
        case .tooManyAnimations(let count): "The pet declares too many animations: \(count)"
        case .tooManyFrames(let animation, let actual): "Animation \(animation) declares too many frames: \(actual)"
        case .invalidNextAnimation(let id): "Animation references an unknown nextAnimation: \(id)"
        case .invalidPose(let animation, let pose): "Animation \(animation) declares an unsupported pose: \(pose)"
        case .missingCanonicalMetadata(let field): "Format 2 is missing canonical metadata: \(field)"
        case .invalidCanonicalMetadata(let field): "Format 2 has invalid canonical metadata: \(field)"
        case .invalidAnchor(let animation, let frame): "Animation \(animation) frame \(frame) has invalid canonical anchors."
        case .invalidEndpointSignature(let animation): "Animation \(animation) has an invalid endpoint pose signature."
        case .invalidIdentityRig(let field): "The canonical identity rig is invalid: \(field)"
        case .invalidComponentPolicy(let field): "The disconnected-component policy is invalid: \(field)"
        }
    }
}

public struct PetManifestValidator: Sendable {
    public init() {}

    public func validate(_ manifest: PetManifest, requireHighFrame: Bool) throws {
        guard (1...2).contains(manifest.formatVersion) else {
            throw PetManifestIssue.unsupportedVersion(manifest.formatVersion)
        }
        let canonical = manifest.formatVersion == 2
        let authoredCanvas: AuthoredCanvas?
        let componentPolicy: PetComponentPolicy?
        if canonical {
            guard manifest.pixelsPerBodyUnit == PetPackageContract.referencePixelsPerBodyUnit else {
                throw PetManifestIssue.invalidCanonicalMetadata("pixelsPerBodyUnit")
            }
            guard let canvas = manifest.authoredCanvas else {
                throw PetManifestIssue.missingCanonicalMetadata("authoredCanvas")
            }
            guard canvas.width > 0, canvas.height > 0,
                  canvas.width <= 8_192, canvas.height <= 8_192,
                  canvas.safeMargin > 0,
                  canvas.safeMargin * 2 < min(canvas.width, canvas.height) else {
                throw PetManifestIssue.invalidCanonicalMetadata("authoredCanvas")
            }
            guard manifest.colorSpace == .canonicalSRGB else {
                throw PetManifestIssue.invalidCanonicalMetadata("colorSpace")
            }
            guard let policy = manifest.componentPolicy else {
                throw PetManifestIssue.missingCanonicalMetadata("componentPolicy")
            }
            try Self.validate(policy)
            guard manifest.identityRig != nil else {
                throw PetManifestIssue.missingCanonicalMetadata("identityRig")
            }
            authoredCanvas = canvas
            componentPolicy = policy
        } else {
            authoredCanvas = nil
            componentPolicy = nil
        }
        let idPattern = /^[a-z0-9][a-z0-9-]{1,63}$/
        guard manifest.id.wholeMatch(of: idPattern) != nil else { throw PetManifestIssue.invalidIdentifier }
        guard (1...80).contains(manifest.displayName.count) else { throw PetManifestIssue.invalidMetadata("displayName") }
        guard (1...120).contains(manifest.author.count) else { throw PetManifestIssue.invalidMetadata("author") }
        guard manifest.description.count <= 500 else { throw PetManifestIssue.invalidMetadata("description") }
        if let assetVersion = manifest.assetVersion, !(1...64).contains(assetVersion.count) {
            throw PetManifestIssue.invalidMetadata("assetVersion")
        }
        guard manifest.pixelsPerBodyUnit.isFinite, manifest.pixelsPerBodyUnit > 0 else {
            throw PetManifestIssue.invalidFrameGeometry("pixelsPerBodyUnit")
        }
        guard AppVersion(manifest.minimumAppVersion) != nil else { throw PetManifestIssue.invalidMinimumAppVersion }
        guard manifest.animations.count <= 128 else { throw PetManifestIssue.tooManyAnimations(manifest.animations.count) }

        var animationIDs = Set<String>()
        var nextAnimationIDs: [String] = []
        var totalFrames = 0
        for animation in manifest.animations {
            guard animation.id.wholeMatch(of: /^[A-Za-z][A-Za-z0-9_-]{0,63}$/) != nil else {
                throw PetManifestIssue.invalidMetadata("animation.id")
            }
            guard animationIDs.insert(animation.id).inserted else { throw PetManifestIssue.duplicateAnimation(animation.id) }
            guard !animation.frames.isEmpty else { throw PetManifestIssue.missingFrames(animation.id) }
            guard animation.frames.count <= 1_000 else {
                throw PetManifestIssue.tooManyFrames(animation: animation.id, actual: animation.frames.count)
            }
            totalFrames += animation.frames.count
            guard totalFrames <= 20_000 else {
                throw PetManifestIssue.tooManyFrames(animation: animation.id, actual: totalFrames)
            }
            if requireHighFrame, animation.frames.count < 24 {
                throw PetManifestIssue.insufficientFrames(animation: animation.id, actual: animation.frames.count)
            }
            for (frameIndex, frame) in animation.frames.enumerated() {
                try Self.validate(
                    frame,
                    context: animation.id,
                    frameIndex: frameIndex,
                    canonicalCanvas: authoredCanvas,
                    componentPolicy: componentPolicy
                )
            }
            if let nextAnimation = animation.nextAnimation { nextAnimationIDs.append(nextAnimation) }
            if let loopStart = animation.loopStartFrame,
               !(0..<animation.frames.count).contains(loopStart) {
                throw PetManifestIssue.invalidFrameGeometry("\(animation.id).loopStartFrame")
            }
            if let startPose = animation.startPose, PetPose(rawValue: startPose) == nil {
                throw PetManifestIssue.invalidPose(animation: animation.id, pose: startPose)
            }
            if let endPose = animation.endPose, PetPose(rawValue: endPose) == nil {
                throw PetManifestIssue.invalidPose(animation: animation.id, pose: endPose)
            }
            if canonical {
                try Self.validateEndpointSignatures(animation)
            }
        }
        guard animationIDs.contains("idle") else { throw PetManifestIssue.missingIdle }
        for nextAnimation in nextAnimationIDs where !animationIDs.contains(nextAnimation) {
            throw PetManifestIssue.invalidNextAnimation(nextAnimation)
        }
        if canonical, let canvas = authoredCanvas,
            let identityRig = manifest.identityRig,
           let policy = componentPolicy {
            try Self.validate(identityRig, canvas: canvas, animations: manifest.animations)
            try Self.validateExceptionBindings(
                policy,
                animations: manifest.animations,
                lookDirections: manifest.lookDirections
            )
        }

        if !manifest.lookDirections.isEmpty {
            let expected = (0..<16).map { Double($0) * 22.5 }
            let actual = manifest.lookDirections.map(\.degrees).sorted()
            guard actual == expected else { throw PetManifestIssue.invalidLookDirections }
            for (frameIndex, direction) in manifest.lookDirections.enumerated() {
                try Self.validate(
                    direction.frame,
                    context: "lookDirections",
                    frameIndex: frameIndex,
                    canonicalCanvas: authoredCanvas,
                    componentPolicy: componentPolicy
                )
            }
        }
    }

    private static func validate(
        _ frame: PetFrame,
        context: String,
        frameIndex: Int,
        canonicalCanvas: AuthoredCanvas?,
        componentPolicy: PetComponentPolicy?
    ) throws {
        guard isSafeResourcePath(frame.image) else { throw PetManifestIssue.invalidFramePath(frame.image) }
        guard frame.sourceSize.width > 0, frame.sourceSize.height > 0,
              frame.trimRect.width > 0, frame.trimRect.height > 0,
              frame.trimRect.x >= 0, frame.trimRect.y >= 0,
              frame.trimRect.x + frame.trimRect.width <= frame.sourceSize.width,
              frame.trimRect.y + frame.trimRect.height <= frame.sourceSize.height,
              (0...1).contains(frame.pivot.x), (0...1).contains(frame.pivot.y) else {
            throw PetManifestIssue.invalidFrameGeometry(context)
        }
        guard (1.0 / 120.0)...1.0 ~= frame.duration else {
            throw PetManifestIssue.invalidFrameDuration(context)
        }
        if let canonicalCanvas {
            if let scale = frame.bodyScale, scale != 1 {
                throw PetManifestIssue.invalidCanonicalMetadata("\(context).bodyScale")
            }
            guard frame.sourceSize == PixelSize(
                width: canonicalCanvas.width,
                height: canonicalCanvas.height
            ) else {
                throw PetManifestIssue.invalidCanonicalMetadata("\(context).sourceSize")
            }
            guard let root = frame.rootAnchor,
                  Self.isValid(root, canvas: canonicalCanvas),
                  let supports = frame.supportAnchors, !supports.isEmpty else {
                throw PetManifestIssue.invalidAnchor(animation: context, frame: frameIndex)
            }
            var supportIDs = Set<String>()
            for support in supports {
                guard support.id.wholeMatch(of: /^[A-Za-z][A-Za-z0-9_-]{0,63}$/) != nil,
                      supportIDs.insert(support.id).inserted,
                      Self.isValid(support.point, canvas: canonicalCanvas) else {
                    throw PetManifestIssue.invalidAnchor(animation: context, frame: frameIndex)
                }
            }
            let expectedPivot = NormalizedPoint(
                x: root.x / Double(canonicalCanvas.width),
                y: root.y / Double(canonicalCanvas.height)
            )
            guard abs(frame.pivot.x - expectedPivot.x) <= 0.000_000_001,
                  abs(frame.pivot.y - expectedPivot.y) <= 0.000_000_001 else {
                throw PetManifestIssue.invalidAnchor(animation: context, frame: frameIndex)
            }
            guard let sourceDigest = frame.sourcePixelSHA256,
                  let atlasDigest = frame.atlasPixelSHA256,
                  Self.isCanonicalDigest(sourceDigest),
                  sourceDigest == atlasDigest else {
                throw PetManifestIssue.invalidCanonicalMetadata("\(context).pixelSHA256")
            }
            if let reviewID = frame.componentExceptionReviewId {
                let matches = componentPolicy?.exceptions.filter {
                    $0.reviewId == reviewID &&
                        $0.animation == context &&
                        $0.frames.contains(frameIndex)
                } ?? []
                guard matches.count == 1 else {
                    throw PetManifestIssue.invalidComponentPolicy(reviewID)
                }
            }
        } else if let scale = frame.bodyScale, !(0.5...3.0).contains(scale) {
            throw PetManifestIssue.invalidFrameGeometry(context)
        }
        if let offset = frame.renderOffset {
            let maximumX = Double(frame.sourceSize.width) * 4
            let maximumY = Double(frame.sourceSize.height) * 4
            guard offset.x.isFinite, offset.y.isFinite,
                  abs(offset.x) <= maximumX, abs(offset.y) <= maximumY else {
                throw PetManifestIssue.invalidFrameGeometry(context)
            }
        }
        if let texture = frame.textureRect,
           (texture.x < 0 || texture.y < 0 || texture.width <= 0 || texture.height <= 0) {
            throw PetManifestIssue.invalidFrameGeometry(context)
        }
        if let collision = frame.collisionRect,
           (collision.x < 0 || collision.y < 0 || collision.width <= 0 || collision.height <= 0 ||
            collision.x + collision.width > frame.sourceSize.width ||
            collision.y + collision.height > frame.sourceSize.height) {
            throw PetManifestIssue.invalidFrameGeometry(context)
        }
    }

    private static func validate(_ policy: PetComponentPolicy) throws {
        guard policy.default == "forbid",
              (1...255).contains(policy.alphaThreshold),
              policy.minimumArea > 0,
              policy.connectivity == 8 else {
            throw PetManifestIssue.invalidComponentPolicy("thresholds")
        }
        var reviewIDs = Set<String>()
        for exception in policy.exceptions {
            guard !exception.reviewId.isEmpty,
                  reviewIDs.insert(exception.reviewId).inserted,
                  exception.issue.wholeMatch(of: /^#[1-9][0-9]*$/) != nil,
                  !exception.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !exception.reviewedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !exception.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  exception.animation.wholeMatch(of: /^[A-Za-z][A-Za-z0-9_-]{0,63}$/) != nil,
                  !exception.frames.isEmpty,
                  exception.frames.allSatisfy({ $0 >= 0 }),
                  Set(exception.frames).count == exception.frames.count,
                  exception.maximumSecondaryComponents > 0,
                  exception.maximumSecondaryArea >= policy.minimumArea else {
                throw PetManifestIssue.invalidComponentPolicy(exception.reviewId)
            }
        }
    }

    private static func validate(
        _ rig: CanonicalIdentityRig,
        canvas: AuthoredCanvas,
        animations: [PetAnimation]
    ) throws {
        let requiredLandmarks: Set<String> = [
            "leftEyeCenter", "rightEyeCenter", "leftEarRoot", "rightEarRoot",
            "nose", "mouth", "shoulder", "hip", "leftForelimbJoint",
            "rightForelimbJoint", "leftHindlimbJoint", "rightHindlimbJoint",
            "tailRoot",
        ]
        let requiredContours: Set<String> = ["headOutline", "faceMaskOutline"]
        guard !rig.views.isEmpty else { throw PetManifestIssue.invalidIdentityRig("views") }
        let byID = Dictionary(uniqueKeysWithValues: animations.map { ($0.id, $0) })
        var viewIDs = Set<String>()
        for view in rig.views {
            guard view.id.wholeMatch(of: /^[A-Za-z][A-Za-z0-9_-]{0,63}$/) != nil,
                  viewIDs.insert(view.id).inserted,
                  let reference = byID[view.referenceAnimation],
                  reference.frames.indices.contains(view.referenceFrame),
                  requiredLandmarks.isSubset(of: Set(view.landmarks.keys)),
                  view.landmarks.values.allSatisfy({ Self.isValid($0, canvas: canvas) }),
                  requiredContours.isSubset(of: Set(view.contours.keys)),
                  view.contours.values.allSatisfy({
                      $0.count >= 3 && $0.allSatisfy { Self.isValid($0, canvas: canvas) }
                  }),
                  !view.materialROIs.isEmpty,
                  view.materialROIs.values.allSatisfy({
                      $0.x >= 0 && $0.y >= 0 && $0.width > 0 && $0.height > 0 &&
                          $0.x + $0.width <= canvas.width &&
                          $0.y + $0.height <= canvas.height
                  }) else {
                throw PetManifestIssue.invalidIdentityRig(view.id)
            }
        }
    }

    private static func validateEndpointSignatures(_ animation: PetAnimation) throws {
        guard let startPose = animation.startPose,
              let endPose = animation.endPose,
              let start = animation.startPoseSignature,
              let end = animation.endPoseSignature,
              start.pose == startPose,
              end.pose == endPose,
              start.frameIndex == 0,
              end.frameIndex == animation.frames.count - 1,
              Self.signature(start, matches: animation.frames[0]),
              Self.signature(end, matches: animation.frames[animation.frames.count - 1]) else {
            throw PetManifestIssue.invalidEndpointSignature(animation.id)
        }
    }

    private static func signature(_ signature: PetPoseSignature, matches frame: PetFrame) -> Bool {
        let contactIDs = (frame.supportAnchors ?? [])
            .filter(\.contact)
            .map(\.id)
            .sorted()
        return signature.pixelSHA256 == frame.atlasPixelSHA256 &&
            signature.rootAnchor == frame.rootAnchor &&
            signature.supportAnchorIDs == contactIDs &&
            Set(signature.supportAnchorIDs).count == signature.supportAnchorIDs.count
    }

    private static func validateExceptionBindings(
        _ policy: PetComponentPolicy,
        animations: [PetAnimation],
        lookDirections: [LookDirection]
    ) throws {
        let byID = Dictionary(uniqueKeysWithValues: animations.map { ($0.id, $0) })
        for exception in policy.exceptions {
            let frames: [PetFrame]?
            if exception.animation == "lookDirections" {
                frames = lookDirections.map(\.frame)
            } else {
                frames = byID[exception.animation]?.frames
            }
            guard let frames,
                  exception.frames.allSatisfy({ frames.indices.contains($0) }),
                  exception.frames.allSatisfy({
                      frames[$0].componentExceptionReviewId == exception.reviewId
                  }) else {
                throw PetManifestIssue.invalidComponentPolicy(exception.reviewId)
            }
        }
    }

    private static func isValid(_ point: PixelPoint, canvas: AuthoredCanvas) -> Bool {
        point.x.isFinite && point.y.isFinite &&
            (0...Double(canvas.width)).contains(point.x) &&
            (0...Double(canvas.height)).contains(point.y)
    }

    private static func isCanonicalDigest(_ value: String) -> Bool {
        value.wholeMatch(of: /^sha256:[0-9a-f]{64}$/) != nil
    }

    public static func isSafeResourcePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~"), !path.contains("\\") else { return false }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }
}

public struct AppVersion: Comparable, Sendable {
    private let components: [Int]

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              parts.compactMap({ Int($0) }).count == parts.count else { return nil }
        components = parts.compactMap { Int($0) }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
