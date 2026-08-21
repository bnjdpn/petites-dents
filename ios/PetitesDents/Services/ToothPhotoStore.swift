import Foundation
import ImageIO
import UniformTypeIdentifiers

/// On-device storage for the photos attached to a tooth.
///
/// Photos live in Application Support, one folder per child and per tooth, and
/// never leave the device: there is no account, no server and no analytics.
/// The folder is deliberately **not** excluded from backup, so changing iPhone
/// does not destroy the memories — the only wording allowed anywhere about
/// this is "your photos stay on your device and exist nowhere else than in
/// your own encrypted Apple backup".
enum ToothPhotoStore {
    enum StoreError: LocalizedError {
        case unreadableImage
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                NSLocalizedString("photos.error_unreadable", comment: "Unreadable photo")
            case .writeFailed:
                NSLocalizedString("photos.error_write", comment: "Photo could not be saved")
            }
        }
    }

    /// Longest edge kept for the stored photo. Big enough for an A4 keepsake
    /// page at 300 dpi, small enough that an album of twenty stays light.
    static let maximumPixelSize = 1_600
    static let thumbnailPixelSize = 240

    static func defaultRootDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("photos", isDirectory: true)
    }

    static func directory(
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) -> URL {
        root
            .appendingPathComponent(sanitized(childID), isDirectory: true)
            .appendingPathComponent(sanitized(toothID), isDirectory: true)
    }

    static func imageURL(
        photoID: String,
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) -> URL {
        directory(childID: childID, toothID: toothID, root: root)
            .appendingPathComponent("\(sanitized(photoID)).jpg")
    }

    static func thumbnailURL(
        photoID: String,
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) -> URL {
        directory(childID: childID, toothID: toothID, root: root)
            .appendingPathComponent("\(sanitized(photoID))-thumb.jpg")
    }

    /// Stores `data` for one tooth and returns the identifier to persist on the
    /// record. Both a display-sized image and a thumbnail are written.
    @discardableResult
    static func store(
        imageData data: Data,
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw StoreError.unreadableImage
        }
        let photoID = UUID().uuidString.lowercased()
        let folder = directory(childID: childID, toothID: toothID, root: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        try write(
            source: source,
            maximumPixelSize: maximumPixelSize,
            to: imageURL(photoID: photoID, childID: childID, toothID: toothID, root: root)
        )
        try write(
            source: source,
            maximumPixelSize: thumbnailPixelSize,
            to: thumbnailURL(photoID: photoID, childID: childID, toothID: toothID, root: root)
        )
        return photoID
    }

    static func data(
        photoID: String,
        childID: String,
        toothID: String,
        thumbnail: Bool = false,
        root: URL = defaultRootDirectory()
    ) -> Data? {
        let url = thumbnail
            ? thumbnailURL(photoID: photoID, childID: childID, toothID: toothID, root: root)
            : imageURL(photoID: photoID, childID: childID, toothID: toothID, root: root)
        return try? Data(contentsOf: url)
    }

    static func delete(
        photoID: String,
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) {
        for url in [
            imageURL(photoID: photoID, childID: childID, toothID: toothID, root: root),
            thumbnailURL(photoID: photoID, childID: childID, toothID: toothID, root: root),
        ] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func deleteAll(
        childID: String,
        toothID: String,
        root: URL = defaultRootDirectory()
    ) {
        try? FileManager.default.removeItem(
            at: directory(childID: childID, toothID: toothID, root: root)
        )
    }

    static func deleteAll(childID: String, root: URL = defaultRootDirectory()) {
        try? FileManager.default.removeItem(
            at: root.appendingPathComponent(sanitized(childID), isDirectory: true)
        )
    }

    private static func write(
        source: CGImageSource,
        maximumPixelSize: Int,
        to url: URL
    ) throws {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw StoreError.unreadableImage
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw StoreError.writeFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw StoreError.writeFailed
        }
    }

    private static func sanitized(_ component: String) -> String {
        let allowed = component.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? character
                : "-"
        }
        let value = String(allowed)
        return value.isEmpty ? "unknown" : value
    }
}
