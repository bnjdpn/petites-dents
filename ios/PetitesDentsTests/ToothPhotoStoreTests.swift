import UIKit
import XCTest
@testable import PetitesDents

final class ToothPhotoStoreTests: XCTestCase {
    private var root = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("petites-dents-photos-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    static func sampleImageData(size: CGSize = CGSize(width: 900, height: 700)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.98, green: 0.84, blue: 0.76, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.51, green: 0.61, blue: 0.48, alpha: 1).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: size.width * 0.3, y: size.height * 0.3,
                           width: size.width * 0.4, height: size.height * 0.4)
            )
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    func testStoringAPhotoWritesBothAFullImageAndAThumbnail() throws {
        let photoID = try ToothPhotoStore.store(
            imageData: Self.sampleImageData(),
            childID: "primary",
            toothID: "tooth-71",
            root: root
        )

        let full = ToothPhotoStore.imageURL(
            photoID: photoID, childID: "primary", toothID: "tooth-71", root: root
        )
        let thumb = ToothPhotoStore.thumbnailURL(
            photoID: photoID, childID: "primary", toothID: "tooth-71", root: root
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: full.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumb.path))

        let fullImage = try XCTUnwrap(UIImage(data: Data(contentsOf: full)))
        let thumbImage = try XCTUnwrap(UIImage(data: Data(contentsOf: thumb)))
        XCTAssertLessThanOrEqual(
            max(fullImage.size.width, fullImage.size.height),
            CGFloat(ToothPhotoStore.maximumPixelSize)
        )
        XCTAssertLessThanOrEqual(
            max(thumbImage.size.width, thumbImage.size.height),
            CGFloat(ToothPhotoStore.thumbnailPixelSize)
        )
        XCTAssertLessThan(thumbImage.size.width, fullImage.size.width)
    }

    func testUnreadableDataIsRejectedRatherThanStored() {
        XCTAssertThrowsError(
            try ToothPhotoStore.store(
                imageData: Data("not an image".utf8),
                childID: "primary",
                toothID: "tooth-71",
                root: root
            )
        )
    }

    func testDeletingOneToothRemovesOnlyItsPhotos() throws {
        let kept = try ToothPhotoStore.store(
            imageData: Self.sampleImageData(), childID: "primary", toothID: "tooth-61", root: root
        )
        _ = try ToothPhotoStore.store(
            imageData: Self.sampleImageData(), childID: "primary", toothID: "tooth-71", root: root
        )

        ToothPhotoStore.deleteAll(childID: "primary", toothID: "tooth-71", root: root)

        XCTAssertNotNil(
            ToothPhotoStore.data(
                photoID: kept, childID: "primary", toothID: "tooth-61", root: root
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: ToothPhotoStore.directory(
                    childID: "primary", toothID: "tooth-71", root: root
                ).path
            )
        )
    }

    func testDeletingAChildRemovesEveryPhotoOfThatChildOnly() throws {
        let otherChild = try ToothPhotoStore.store(
            imageData: Self.sampleImageData(), childID: "lina", toothID: "tooth-71", root: root
        )
        _ = try ToothPhotoStore.store(
            imageData: Self.sampleImageData(), childID: "primary", toothID: "tooth-71", root: root
        )

        ToothPhotoStore.deleteAll(childID: "primary", root: root)

        XCTAssertNotNil(
            ToothPhotoStore.data(
                photoID: otherChild, childID: "lina", toothID: "tooth-71", root: root
            )
        )
        XCTAssertNil(
            ToothPhotoStore.data(
                photoID: "any", childID: "primary", toothID: "tooth-71", root: root
            )
        )
    }
}
