import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import SynthesisCore

struct WorldImageExportTests {
  @Test func validGrayscaleAlphaPNGIsPreservedExactlyInsteadOfBeingSilentlyDropped() throws {
    let png = RecordArtworkTests.png
    #expect(try WorldImageExport.pngData(png) == png)
    #expect(throws: SynthesisError.self) { try WorldImageExport.pngData(Data("broken image".utf8)) }
  }

  @Test func jpegInputsProduceDecodablePNGExports() throws {
    let context = try #require(
      CGContext(
        data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let image = try #require(context.makeImage())
    let jpeg = NSMutableData()
    let writer = try #require(
      CGImageDestinationCreateWithData(jpeg, "public.jpeg" as CFString, 1, nil))
    CGImageDestinationAddImage(writer, image, nil)
    #expect(CGImageDestinationFinalize(writer))
    let png = try WorldImageExport.pngData(jpeg as Data)
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    #expect(CGImageSourceGetType(source) as String? == "public.png")
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(decoded.width == 2 && decoded.height == 2)
  }
}
