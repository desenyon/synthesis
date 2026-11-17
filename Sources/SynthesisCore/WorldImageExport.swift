import Foundation
import ImageIO

/// Normalize raster exports without round-tripping already valid PNGs through AppKit's
/// bitmap encoder. In particular, valid grayscale/alpha PNGs can fail that encoder.
public enum WorldImageExport {
  public static func pngData(_ data: Data) throws -> Data {
    guard !data.isEmpty, data.count <= 20_000_000,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let type = CGImageSourceGetType(source) as String?,
      let image = CGImageSourceCreateImageAtIndex(
        source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
    else {
      throw SynthesisError.invalid(
        "A saved image could not be decoded for export. The original image is preserved in the world."
      )
    }
    if type == "public.png" { return data }
    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
    else {
      throw SynthesisError.invalid("A PNG image export could not be prepared.")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw SynthesisError.invalid(
        "A saved image could not be converted to PNG. The original image is preserved in the world."
      )
    }
    return output as Data
  }
}
