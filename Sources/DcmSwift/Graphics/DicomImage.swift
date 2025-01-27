//
//  DicomImage.swift
//  DcmSwift
//
//  Created by Rafael Warnault, OPALE on 30/10/2017.
//  Modified by Victor Alves on Jan 2025 to add VisionOS support.
//

import Foundation

#if os(macOS)
  import Quartz
  import AppKit
#elseif os(iOS) || os(visionOS)
  import UIKit
  import SwiftUI
#endif

// NSImage and Data extensions remain unchanged for macOS
#if os(macOS)
  extension NSImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
  }

  extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
  }

  extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
  }
#endif
// MARK: - DicomImage Class

/// DicomImage is a wrapper that provides image-related features for the DICOM standard.
/// Please refer to dicomiseasy : http://dicomiseasy.blogspot.com/2012/08/chapter-12-pixel-data.html
public class DicomImage {

  // MARK: - Enums

  /// Color space of the image
  public enum PhotometricInterpretation {
    case MONOCHROME1
    case MONOCHROME2
    case PALETTE_COLOR
    case RGB
    case HSV
    case ARGB
    case CMYK
    case YBR_FULL
    case YBR_FULL_422
    case YBR_PARTIAL_422
    case YBR_PARTIAL_420
    case YBR_ICT
    case YBR_RCT
  }

  /// Indicates if a pixel is signed or unsigned
  public enum PixelRepresentation: Int {
    case Unsigned = 0
    case Signed = 1
  }

  // MARK: - Properties

  private var dataset: DataSet!
  private var frames: [Data] = []

  public var photoInter = PhotometricInterpretation.RGB
  public var pixelRepresentation = PixelRepresentation.Unsigned
  public var colorSpace = CGColorSpaceCreateDeviceRGB()

  public var isMultiframe = false
  public var isMonochrome = false

  public var numberOfFrames = 0
  public var rows = 0
  public var columns = 0

  public var windowWidth = -1
  public var windowCenter = -1
  public var rescaleSlope = 1
  public var rescaleIntercept = 0

  public var samplesPerPixel = 0
  public var bitsAllocated = 0
  public var bitsStored = 0
  public var bitsPerPixel = 0
  public var bytesPerRow = 0

  // MARK: - Initializer

  public init?(_ dataset: DataSet) {
    self.dataset = dataset

    // Parse Photometric Interpretation
    if let pi = self.dataset.string(forTag: "PhotometricInterpretation") {
      let trimmedPI = pi.trimmingCharacters(in: .whitespaces)
      switch trimmedPI {
      case "MONOCHROME1":
        self.photoInter = .MONOCHROME1
        self.isMonochrome = true
      case "MONOCHROME2":
        self.photoInter = .MONOCHROME2
        self.isMonochrome = true
      case "ARGB":
        self.photoInter = .ARGB
      case "RGB":
        self.photoInter = .RGB
      default:
        break
      }
    }

    // Parse Rows and Columns
    if let v = self.dataset.integer16(forTag: "Rows") {
      self.rows = Int(v)
    }

    if let v = self.dataset.integer16(forTag: "Columns") {
      self.columns = Int(v)
    }

    // Parse Window Width and Center
    if let v = self.dataset.string(forTag: "WindowWidth") {
      self.windowWidth = Int(v) ?? self.windowWidth
    }

    if let v = self.dataset.string(forTag: "WindowCenter") {
      self.windowCenter = Int(v) ?? self.windowCenter
    }

    // Parse Rescale Slope and Intercept
    if let v = self.dataset.string(forTag: "RescaleSlope") {
      self.rescaleSlope = Int(v) ?? self.rescaleSlope
    }

    if let v = self.dataset.string(forTag: "RescaleIntercept") {
      self.rescaleIntercept = Int(v) ?? self.rescaleIntercept
    }

    // Parse Bits Allocated, Stored, and Per Pixel
    if let v = self.dataset.integer16(forTag: "BitsAllocated") {
      self.bitsAllocated = Int(v)
    }

    if let v = self.dataset.integer16(forTag: "BitsStored") {
      self.bitsStored = Int(v)
    }

    if let v = self.dataset.integer16(forTag: "SamplesPerPixel") {
      self.samplesPerPixel = Int(v)
    }

    // Parse Pixel Representation
    if let v = self.dataset.integer16(forTag: "PixelRepresentation") {
      self.pixelRepresentation = v == 0 ? .Unsigned : .Signed
    }

    // Determine if Image is Multiframe
    if self.dataset.hasElement(forTagName: "PixelData") {
      self.numberOfFrames = 1
    }

    if let nofString = self.dataset.string(forTag: "NumberOfFrames") {
      if let nof = Int(nofString) {
        self.isMultiframe = true
        self.numberOfFrames = nof
      }
    }

    // Logging
    Logger.verbose("  -> rows : \(self.rows)")
    Logger.verbose("  -> columns : \(self.columns)")
    Logger.verbose("  -> photoInter : \(photoInter)")
    Logger.verbose("  -> isMultiframe : \(isMultiframe)")
    Logger.verbose("  -> numberOfFrames : \(numberOfFrames)")
    Logger.verbose("  -> samplesPerPixel : \(samplesPerPixel)")
    Logger.verbose("  -> bitsAllocated : \(bitsAllocated)")
    Logger.verbose("  -> bitsStored : \(bitsStored)")

    // Load Pixel Data
    self.loadPixelData()
  }

  // MARK: - Image Creation Methods

  #if os(macOS) || os(iOS) || os(visionOS)
    public func image(forFrame frame: Int) -> Any? {
      guard frames.indices.contains(frame) else {
        Logger.error("  -> No such frame (\(frame))")
        return nil
      }

      let size = CGSize(width: self.columns, height: self.rows)
      let data = self.frames[frame]

      if TransferSyntax.transfersSyntaxes.contains(self.dataset.transferSyntax.tsUID) {
        if let cgim = self.imageFromPixels(
          size: size, pixels: data.toUnsigned8Array(), width: self.columns, height: self.rows)
        {
          #if os(macOS)
            return NSImage(cgImage: cgim, size: size)
          #elseif os(iOS)
            return UIImage(cgImage: cgim, scale: 1.0, orientation: .up)
          #elseif os(visionOS)
            return Image(decorative: cgim, scale: 1.0, orientation: .up)
          #endif
        }
      } else {
        #if os(macOS)
          return NSImage(data: data)
        #elseif os(iOS)
          return UIImage(data: data)
        #elseif os(visionOS)
          if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
          }
        #endif
      }

      return nil
    }
  #endif

  #if os(visionOS)
    public func swiftUIImage(forFrame frame: Int) -> Image? {
      guard let image = self.image(forFrame: frame) as? Image else {
        Logger.error("  -> Failed to cast image to SwiftUI Image for VisionOS")
        return nil
      }
      return image
    }
  #endif

  // MARK: - Private Methods

  /**
     Converts raw pixel data into a `CGImage`.
     - Parameters:
        - size: The size of the image.
        - pixels: Pointer to the pixel data.
        - width: Width of the image in pixels.
        - height: Height of the image in pixels.
     - Returns: A `CGImage` object if successful, otherwise `nil`.
     */
  private func imageFromPixels(size: CGSize, pixels: UnsafeRawPointer, width: Int, height: Int)
    -> CGImage?
  {
    var bitmapInfo: CGBitmapInfo = []

    if self.isMonochrome {
      self.colorSpace = CGColorSpaceCreateDeviceGray()
      // Additional monochrome-specific configurations can be added here
    } else {
      if self.photoInter != .ARGB {
        bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
      }
    }

    self.bitsPerPixel = self.samplesPerPixel * self.bitsStored
    self.bytesPerRow = width * (self.bitsAllocated / 8) * samplesPerPixel
    let dataLength = height * bytesPerRow

    Logger.verbose("  -> width : \(width)")
    Logger.verbose("  -> height : \(height)")
    Logger.verbose("  -> bytesPerRow : \(bytesPerRow)")
    Logger.verbose("  -> bitsPerPixel : \(bitsPerPixel)")
    Logger.verbose("  -> dataLength : \(dataLength)")

    let imageData = NSData(bytes: pixels, length: dataLength)
    guard let providerRef = CGDataProvider(data: imageData) else {
      Logger.error("  -> FATAL: cannot allocate bitmap properly")
      return nil
    }

    guard
      let cgim = CGImage(
        width: width,
        height: height,
        bitsPerComponent: self.bitsAllocated,
        bitsPerPixel: self.bitsPerPixel,
        bytesPerRow: self.bytesPerRow,
        space: self.colorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
      )
    else {
      Logger.error("  -> FATAL: invalid bitmap for CGImage")
      return nil
    }

    return cgim
  }

  /**
     Processes presentation values such as rescale intercept, slope, window center, and width.
     - Parameter pixels: The raw pixel data.
     - Returns: An array of processed pixel data.
     */
  private func processPresentationValues(pixels: [UInt8]) -> [UInt8] {
    var output: [UInt8] = pixels

    Logger.verbose("  -> rescaleIntercept : \(self.rescaleIntercept)")
    Logger.verbose("  -> rescaleSlope : \(self.rescaleSlope)")
    Logger.verbose("  -> windowCenter : \(self.windowCenter)")
    Logger.verbose("  -> windowWidth : \(self.windowWidth)")

    // Apply rescale slope and intercept if necessary
    if rescaleIntercept != 0 || rescaleSlope != 1 {
      output = pixels.map { (b) -> UInt8 in
        let scaled = (UInt16(rescaleSlope) * UInt16(b)) + UInt16(rescaleIntercept)
        return UInt8(clamping: scaled)
      }
    }

    // Apply windowing if necessary
    if self.windowWidth != -1 && self.windowCenter != -1 {
      let low = windowCenter - windowWidth / 2
      let high = windowCenter + windowWidth / 2

      Logger.verbose("  -> low  : \(low)")
      Logger.verbose("  -> high : \(high)")

      for i in 0..<output.count {
        if output[i] < low {
          output[i] = UInt8(low)
        } else if output[i] > high {
          output[i] = UInt8(high)
        }
      }
    }

    return output
  }

  /**
     Writes a DICOM image to PNG files at the specified path with an optional base name.
     - Parameters:
        - path: The directory path where PNG files will be saved.
        - baseName: The base name for the PNG files. If `nil`, a UID is generated.
     */
  public func toPNG(path: String, baseName: String?) {
    let baseFilename = baseName.map { "\($0)_" } ?? "\(UID.generate())_"

    for frame in 0..<numberOfFrames {
      guard let image = self.image(forFrame: frame) else { continue }

      let filePath = URL(fileURLWithPath: path).appendingPathComponent(
        "\(baseFilename)\(frame).png")
      Logger.debug(filePath.absoluteString)

      #if os(macOS)
        if let nsImage = image as? NSImage, let data = nsImage.png {
          try? data.write(to: filePath)
        }
      #elseif os(iOS)
        if let uiImage = image as? UIImage, let data = uiImage.pngData() {
          try? data.write(to: filePath)
        }
      #elseif os(visionOS)
        if let swiftUIImage = image as? Image {
          // VisionOS workaround: Convert SwiftUI Image to UIImage first (if needed)
          Logger.warning(
            "VisionOS does not natively support direct PNG export. Implement conversion if necessary."
          )
        }
      #endif
    }
  }
  /**
     Loads pixel data from the dataset into the `frames` array.
     */
  public func loadPixelData() {
    // Refuse NON native DICOM TS for now
    // if !DicomConstants.transfersSyntaxes.contains(self.dataset.transferSyntax) {
    //     Logger.error("  -> Unsupported Transfer Syntax")
    //     return;
    // }

    if let pixelDataElement = self.dataset.element(forTagName: "PixelData") {
      // Pixel Sequence multiframe
      if let seq = pixelDataElement as? DataSequence {
        for item in seq.items {
          if let data = item.data, item.length > 128 {
            self.frames.append(data)
          }
        }
      } else {
        // OW/OB multiframe
        if self.numberOfFrames > 1 {
          let frameSize = pixelDataElement.length / self.numberOfFrames
          let chunks = pixelDataElement.data.toUnsigned8Array().chunked(into: frameSize)

          for chunk in chunks {
            self.frames.append(Data(chunk))
          }
        } else {
          // Single image
          if let data = pixelDataElement.data {
            self.frames.append(data)
          }
        }
      }
    }
  }
}
