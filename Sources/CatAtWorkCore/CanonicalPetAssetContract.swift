import Foundation

public struct AuthoredCanvas: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var safeMargin: Int

    public init(width: Int, height: Int, safeMargin: Int) {
        self.width = width
        self.height = height
        self.safeMargin = safeMargin
    }
}

public struct PetColorContract: Codable, Hashable, Sendable {
    public var name: String
    public var pixelFormat: String
    public var alphaMode: String
    public var conversion: String

    public init(
        name: String = "sRGB",
        pixelFormat: String = "RGBA8",
        alphaMode: String = "straight",
        conversion: String = "identity"
    ) {
        self.name = name
        self.pixelFormat = pixelFormat
        self.alphaMode = alphaMode
        self.conversion = conversion
    }

    public static let canonicalSRGB = PetColorContract()
}

public struct PetSupportAnchor: Codable, Hashable, Sendable {
    public var id: String
    public var point: PixelPoint
    public var contact: Bool

    public init(id: String, point: PixelPoint, contact: Bool) {
        self.id = id
        self.point = point
        self.contact = contact
    }
}

public struct ReviewedComponentException: Codable, Hashable, Sendable {
    public var reviewId: String
    public var issue: String
    public var owner: String
    public var reviewedBy: String
    public var reason: String
    public var animation: String
    public var frames: [Int]
    public var maximumSecondaryComponents: Int
    public var maximumSecondaryArea: Int

    public init(
        reviewId: String,
        issue: String,
        owner: String,
        reviewedBy: String,
        reason: String,
        animation: String,
        frames: [Int],
        maximumSecondaryComponents: Int,
        maximumSecondaryArea: Int
    ) {
        self.reviewId = reviewId
        self.issue = issue
        self.owner = owner
        self.reviewedBy = reviewedBy
        self.reason = reason
        self.animation = animation
        self.frames = frames
        self.maximumSecondaryComponents = maximumSecondaryComponents
        self.maximumSecondaryArea = maximumSecondaryArea
    }
}

public struct PetComponentPolicy: Codable, Hashable, Sendable {
    public var `default`: String
    public var alphaThreshold: Int
    public var minimumArea: Int
    public var connectivity: Int
    public var exceptions: [ReviewedComponentException]

    public init(
        default: String = "forbid",
        alphaThreshold: Int = 12,
        minimumArea: Int = 4,
        connectivity: Int = 8,
        exceptions: [ReviewedComponentException] = []
    ) {
        self.default = `default`
        self.alphaThreshold = alphaThreshold
        self.minimumArea = minimumArea
        self.connectivity = connectivity
        self.exceptions = exceptions
    }
}

public struct CanonicalIdentityView: Codable, Hashable, Sendable {
    public var id: String
    public var referenceAnimation: String
    public var referenceFrame: Int
    public var landmarks: [String: PixelPoint]
    public var contours: [String: [PixelPoint]]
    public var materialROIs: [String: PixelRect]

    public init(
        id: String,
        referenceAnimation: String,
        referenceFrame: Int,
        landmarks: [String: PixelPoint],
        contours: [String: [PixelPoint]],
        materialROIs: [String: PixelRect]
    ) {
        self.id = id
        self.referenceAnimation = referenceAnimation
        self.referenceFrame = referenceFrame
        self.landmarks = landmarks
        self.contours = contours
        self.materialROIs = materialROIs
    }
}

public struct CanonicalIdentityRig: Codable, Hashable, Sendable {
    public var views: [CanonicalIdentityView]

    public init(views: [CanonicalIdentityView]) {
        self.views = views
    }
}

public struct PetPoseSignature: Codable, Hashable, Sendable {
    public var pose: String
    public var frameIndex: Int
    public var pixelSHA256: String
    public var rootAnchor: PixelPoint
    public var supportAnchorIDs: [String]

    public init(
        pose: String,
        frameIndex: Int,
        pixelSHA256: String,
        rootAnchor: PixelPoint,
        supportAnchorIDs: [String]
    ) {
        self.pose = pose
        self.frameIndex = frameIndex
        self.pixelSHA256 = pixelSHA256
        self.rootAnchor = rootAnchor
        self.supportAnchorIDs = supportAnchorIDs
    }
}

public enum PetPackageCompatibilityMode: String, Codable, Hashable, Sendable {
    case legacyFormat1
    case canonicalFormat2
}
