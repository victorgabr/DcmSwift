import DcmSwift
import Foundation  // Ensure Foundation is imported
//
//  DcmSwiftTests.swift
//  DcmSwiftTests
//
//  Created by Rafael Warnault, OPALE on 29/10/2017.
//  Copyright © 2017 OPALE, Rafaël Warnault. All rights reserved.
//
import XCTest

#if os(macOS)
    import AppKit
#elseif os(iOS) || os(visionOS)
    import UIKit
#endif

/// This class provides a suite of unit tests to qualify DcmSwift framework features.
///
/// It is sort of decomposed by categories using boolean attributes you can toggle to target some features
/// more easily (`testDicomFileRead`, `testDicomFileWrite`, `testDicomImage`, etc.)
///
/// Some of the tests, especially those done around actual files, are dynamically generated using NSInvocation
/// for better integration and readability.
class DcmSwiftTests: XCTestCase {
    // Configure the test suite with the following boolean attributes

    /// Run tests on DICOM Date and Time
    private static var testDicomDateAndTime = true

    /// Run tests to read files (rely on embedded test files, dynamically generated)
    private static var testDicomFileRead = true

    /// Run tests to write files (rely on embedded test files, dynamically generated)
    private static var testDicomFileWrite = true

    /// Run tests to update dataset (rely on embedded test files, dynamically generated)
    private static var testDicomDataSet = false

    /// Run tests to read image(s) (rely on embedded test files, dynamically generated)
    private static var testDicomImage = false

    /// Run DicomRT helpers tests
    private static var testRT = true

    internal var filePath: String!
    private var finderTestDir: String = ""
    private var printDatasets = false

    /**
     We mostly prepare the output directory for test to write test files back.
     */
    override func setUp() {
        super.setUp()

        // prepare a test output directory for rewritten files
        self.finderTestDir = String(
            NSString(string: "~/Desktop/DcmSwiftTests").expandingTildeInPath)

        do {
            try FileManager.default.createDirectory(
                atPath: self.finderTestDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
    }

    override func tearDown() {
        // code here
        super.tearDown()
    }

    /**
     Override defaultTestSuite to ease generation of dynamic tests
     and coustomized configuration using boolean attributes
     */
    override class var defaultTestSuite: XCTestSuite {
        let suite = XCTestSuite(forTestCaseClass: DcmSwiftTests.self)
        let paths = Bundle.module.paths(forResourcesOfType: "dcm", inDirectory: nil)

        if testDicomDateAndTime {
            suite.addTest(DcmSwiftTests(selector: #selector(readDicomDate)))
            suite.addTest(DcmSwiftTests(selector: #selector(writeDicomDate)))
            suite.addTest(DcmSwiftTests(selector: #selector(dicomDateWrongLength)))
            suite.addTest(DcmSwiftTests(selector: #selector(readDicomTimeMidnight)))
            // TODO: fix it!?
            //suite.addTest(DcmSwiftTests(selector: #selector(dicomTimeWrongLength)))
            suite.addTest(DcmSwiftTests(selector: #selector(dicomTimeWeirdTime)))
            suite.addTest(DcmSwiftTests(selector: #selector(readDicomTime)))
            suite.addTest(DcmSwiftTests(selector: #selector(writeDicomTime)))
            suite.addTest(DcmSwiftTests(selector: #selector(combineDateAndTime)))
            suite.addTest(DcmSwiftTests(selector: #selector(readWriteDicomRange)))
        }

        if testDicomFileRead {
            paths.forEach { path in
                let block: @convention(block) (DcmSwiftTests) -> Void = { t in
                    _ = t.readFile(withPath: path)
                }

                DcmSwiftTests.addFileTest(
                    withName: "FileRead", inSuite: suite, withPath: path, block: block)
            }
        }

        if testDicomFileWrite {
            /**
             This test suite performs a read/write on a set of DICOM files without
             modifying them, them check the MD5 checksum to ensure the I/O features
             of DcmSwift work properly.
             */
            paths.forEach { path in
                let block: @convention(block) (DcmSwiftTests) -> Void = { t in
                    t.readWriteTest()
                }

                DcmSwiftTests.addFileTest(
                    withName: "FileWrite", inSuite: suite, withPath: path, block: block)
            }
        }

        if testDicomDataSet {
            paths.forEach { path in
                let block: @convention(block) (DcmSwiftTests) -> Void = { t in
                    t.readUpdateWriteTest()
                }

                DcmSwiftTests.addFileTest(
                    withName: "DataSet", inSuite: suite, withPath: path, block: block)
            }
        }

        if testDicomImage {
            paths.forEach { path in
                let block: @convention(block) (DcmSwiftTests) -> Void = { t in
                    t.readImageTest()
                }

                DcmSwiftTests.addFileTest(
                    withName: "DicomImage", inSuite: suite, withPath: path, block: block)
            }
        }

        if testRT {
            suite.addTest(DcmSwiftTests(selector: #selector(testIsValid)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetDoseImageWidth)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetDoseImageHeight)))
            suite.addTest(DcmSwiftTests(selector: #selector(testToPNG)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetUnscaledDose)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetDose)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetDoseImage)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetDoseImages)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetPatientItem)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetBeamItem)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetFractionGroupItem)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetToleranceTableItem)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetFrameOfReference)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetObservation)))
            suite.addTest(DcmSwiftTests(selector: #selector(testGetObservationByROINumber)))
        }

        return suite
    }

    private class func addFileTest(
        withName name: String, inSuite suite: XCTestSuite, withPath path: String, block: Any
    ) {
        var fileName = String((path as NSString).deletingPathExtension.split(separator: "/").last!)
        fileName = (fileName as NSString).replacingOccurrences(of: "-", with: "_")

        // with help of ObjC runtime we add new test method to class
        let implementation = imp_implementationWithBlock(block)
        let selectorName = "test_\(name)_\(fileName)"
        let selector = NSSelectorFromString(selectorName)

        class_addMethod(DcmSwiftTests.self, selector, implementation, "v@:")

        // Generate a test for our specific selector
        let test = DcmSwiftTests(selector: selector)

        // Each test will take the size argument and use the instance variable in the test
        test.filePath = path

        // Add it to the suite, and the defaults handle the rest
        suite.addTest(test)
    }

    // MARK: -
    public func readDicomDate() {
        let ds1 = "20001201"
        let dd1 = Date(dicomDate: ds1)

        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let expected_res = "2000/12/01 00:00:00"

        XCTAssert(expected_res == df.string(from: dd1!))

        // ACR-NEMA date format
        let ds2 = "2000.12.01"
        let dd2 = Date(dicomDate: ds2)

        XCTAssert(expected_res == df.string(from: dd2!))
    }

    public func writeDicomDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"

        let ds1 = "2012/01/24"
        let d1 = dateFormatter.date(from: ds1)
        let dd1 = d1!.dicomDateString()

        XCTAssert(dd1 == "20120124")
    }

    public func dicomDateWrongLength() {
        // Must be 8 or 10 bytes
        var ds = ""
        for i in 0...11 {
            if i == 8 || i == 10 {
                ds += "1"
                continue
            }

            let dd = Date(dicomDate: ds)
            XCTAssert(dd == nil)

            ds += "1"
        }
    }

    public func readDicomTime() {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let expected_res = "2000/01/01 14:32:50"

        let ds1 = "143250"
        let dd1 = Date(dicomTime: ds1)

        XCTAssert(expected_res == df.string(from: dd1!))

        // ACR-NEMA time format
        let ds2 = "14:32:50"
        let dd2 = Date(dicomTime: ds2)

        XCTAssert(expected_res == df.string(from: dd2!))
    }

    public func readDicomTimeMidnight() {
        let ds1 = "240000"
        let dd1 = Date(dicomTime: ds1)

        XCTAssert(dd1 == nil)

        // ACR-NEMA time format
        let ds2 = "24:00:00"
        let dd2 = Date(dicomTime: ds2)

        XCTAssert(dd2 == nil)
    }

    //    public func dicomTimeWrongLength() {
    //        var ds1 = "1"
    //        for _ in 0...3 {
    //            print("ds1  \(ds1)")
    //            let dd1 = Date(dicomTime: ds1)
    //            XCTAssert(dd1 == nil)
    //            ds1 += "11"
    //        }
    //    }

    public func dicomTimeWeirdTime() {
        let ds1 = "236000"
        let dd1 = Date(dicomTime: ds1)

        XCTAssert(dd1 == nil)

        let ds2 = "235099"
        let dd2 = Date(dicomTime: ds2)

        XCTAssert(dd2 == nil)

        let ds3 = "255009"
        let dd3 = Date(dicomTime: ds3)

        XCTAssert(dd3 == nil)
    }

    public func writeDicomTime() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        let ds1 = "14:32:50"
        let d1 = dateFormatter.date(from: ds1)
        let dd1 = d1!.dicomTimeString()

        XCTAssert(dd1 == "143250.000000")
    }

    public func combineDateAndTime() {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let expected_res = "2000/12/01 14:32:50"

        let ds1 = "20001201"
        let ts1 = "143250"

        let dateAndTime = Date(dicomDate: ds1, dicomTime: ts1)

        XCTAssert(expected_res == df.string(from: dateAndTime!))
    }

    public func readWriteDicomRange() {
        let ds1 = "20001201"
        let ds2 = "20021201"

        let dicomRange = "\(ds1)-\(ds2)"
        let dateRange = DateRange(dicomRange: dicomRange, type: VR.VR.DA)

        XCTAssert(dateRange!.range == .between)
        XCTAssert(dateRange!.description == "20001201-20021201")
    }

    public func readWriteTest() {
        XCTAssert(self.readWriteFile(withPath: self.filePath))
    }

    public func readTest() {
        XCTAssert(self.readFile(withPath: self.filePath))
    }

    public func readUpdateWriteTest() {
        XCTAssert(self.readUpdateWriteFile(withPath: self.filePath))
    }

    public func readImageTest() {
        XCTAssert(self.readImageFile(withPath: self.filePath))
    }

    private func readImageFile(withPath path: String, checksum: Bool = true) -> Bool {
        let fileName = path.components(separatedBy: "/").last!.replacingOccurrences(
            of: ".dcm", with: "")
        var writePath = "\(self.finderTestDir)/\(fileName)-rwi-test.png"

        Logger.info("#########################################################")
        Logger.info("# PIXEL DATA TEST")
        Logger.info("#")
        Logger.info("# Source file : \(path)")
        Logger.info("# Destination file : \(writePath)")
        Logger.info("#")

        // Open the DICOM file
        if let dicomFile = DicomFile(forPath: path) {
            if printDatasets {
                Logger.info("\(dicomFile.dataset.description)")
            }

            Logger.info("# Read succeeded")

            // Extract the DICOM image
            if let dicomImage = dicomFile.dicomImage {
                for i in 0..<1 {
                    writePath = "\(self.finderTestDir)/\(fileName)-rwi-test-\(i)"

                    if let image = dicomImage.image(forFrame: i) {
                        // Check the transfer syntax and write the image accordingly
                        if dicomFile.dataset.transferSyntax == TransferSyntax.JPEG2000
                            || dicomFile.dataset.transferSyntax == TransferSyntax.JPEG2000Part2
                            || dicomFile.dataset.transferSyntax
                                == TransferSyntax.JPEG2000LosslessOnly
                            || dicomFile.dataset.transferSyntax
                                == TransferSyntax.JPEG2000Part2Lossless
                        {
                            #if os(macOS)
                                if let nsImage = image as? NSImage {
                                    _ = nsImage.writeToFile(
                                        file: writePath, atomically: true, usingType: .jpeg2000)
                                }
                            #elseif os(iOS) || os(visionOS)
                                if let uiImage = image as? UIImage,
                                    let data = uiImage.jpegData(compressionQuality: 1.0)
                                {
                                    do {
                                        try data.write(to: URL(fileURLWithPath: writePath))
                                    } catch {
                                        Logger.error(
                                            "Error writing JPEG2000 image on iOS/visionOS: \(error)"
                                        )
                                        return false
                                    }
                                }
                            #endif
                        } else if dicomFile.dataset.transferSyntax == TransferSyntax.JPEGLossless
                            || dicomFile.dataset.transferSyntax
                                == TransferSyntax.JPEGLosslessNonhierarchical
                        {
                            #if os(macOS)
                                if let nsImage = image as? NSImage {
                                    _ = nsImage.writeToFile(
                                        file: writePath, atomically: true, usingType: .jpeg)
                                }
                            #elseif os(iOS) || os(visionOS)
                                if let uiImage = image as? UIImage,
                                    let data = uiImage.jpegData(compressionQuality: 1.0)
                                {
                                    do {
                                        try data.write(to: URL(fileURLWithPath: writePath))
                                    } catch {
                                        Logger.error(
                                            "Error writing JPEG image on iOS/visionOS: \(error)")
                                        return false
                                    }
                                }
                            #endif
                        } else {
                            #if os(macOS)
                                if let nsImage = image as? NSImage {
                                    _ = nsImage.writeToFile(
                                        file: writePath, atomically: true, usingType: .bmp)
                                }
                            #elseif os(iOS) || os(visionOS)
                                if let uiImage = image as? UIImage, let data = uiImage.pngData() {
                                    do {
                                        try data.write(to: URL(fileURLWithPath: writePath))
                                    } catch {
                                        Logger.error(
                                            "Error writing BMP image on iOS/visionOS: \(error)")
                                        return false
                                    }
                                }
                            #endif
                        }
                    } else {
                        Logger.info("# Error: while extracting Pixel Data")
                        Logger.info("#")
                        Logger.info("#########################################################")
                        return false
                    }
                }
            } else {
                Logger.info("# Error: while extracting Pixel Data")
                Logger.info("#")
                Logger.info("#########################################################")
                return false
            }

            Logger.info("#")
            Logger.info("#########################################################")
            return true
        }

        return false
    }

    /**
     This test reads a source DICOM file, updates its PatientName attribute, then writes a DICOM file copy.
     Then it re-reads the just updated DICOM file to set back its original PatientName and then checks data integrity against the source DICOM file using MD5
     */
    private func readUpdateWriteFile(withPath path: String, checksum: Bool = true) -> Bool {
        let fileName = path.components(separatedBy: "/").last!.replacingOccurrences(
            of: ".dcm", with: "")
        let writePath = "\(self.finderTestDir)/\(fileName)-rwu-test.dcm"

        Logger.info("#########################################################")
        Logger.info("# UPDATE INTEGRITY TEST")
        Logger.info("#")
        Logger.info("# Source file : \(path)")
        Logger.info("# Destination file : \(writePath)")
        Logger.info("#")

        if let dicomFile = DicomFile(forPath: path) {
            if printDatasets { Logger.info("\(dicomFile.dataset.description )") }

            Logger.info("# Read succeeded")

            let oldPatientName = dicomFile.dataset.string(forTag: "PatientName")

            if dicomFile.dataset.set(value: "Dicomix", forTagName: "PatientName") != nil {
                Logger.info("# Update succeeded")
            } else {
                Logger.error("# Update failed")
            }

            if dicomFile.write(atPath: writePath) {
                Logger.info("# Write succeeded")
                Logger.info("#")

                if let newDicomFile = DicomFile(forPath: writePath) {
                    Logger.info("# Re-read updated file read succeeded !!!")
                    Logger.info("#")

                    if oldPatientName == nil {
                        Logger.error("# DICOM object do not provide a PatientName")
                        return false
                    }

                    if newDicomFile.dataset.set(value: oldPatientName!, forTagName: "PatientName")
                        != nil
                    {
                        Logger.error("# Restore PatientName failed")
                        return false
                    }

                    if !newDicomFile.write(atPath: writePath) {
                        Logger.error("# Cannot write restored DICOM object")
                        return false
                    }

                    let originalSum = shell(launchPath: "/sbin/md5", arguments: ["-q", path])
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    let savedSum = shell(launchPath: "/sbin/md5", arguments: ["-q", writePath])
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                    Logger.info("# Source file MD5 : \(originalSum)")
                    Logger.info("# Dest. file MD5  : \(savedSum)")
                    Logger.info("#")

                    if originalSum == savedSum {
                        Logger.info("# Checksum succeeded: \(originalSum) == \(savedSum)")
                    } else {
                        Logger.info("# Error: wrong checksum: \(originalSum) != \(savedSum)")
                        Logger.info("#")
                        Logger.info("#########################################################")
                        return false
                    }

                } else {
                    Logger.error("# Re-read updated file read failed…")
                    Logger.info("#")
                    Logger.info("#########################################################")
                    return false
                }
            } else {
                Logger.error("# Error: while writing file: \(writePath)")
                Logger.info("#")
                Logger.info("#########################################################")
                return false
            }

            Logger.info("#")
            Logger.info("#########################################################")

            return true
        }

        return true
    }

    private func readWriteFile(withPath path: String, checksum: Bool = true) -> Bool {
        let fileName = path.components(separatedBy: "/").last!.replacingOccurrences(
            of: ".dcm", with: "")
        let writePath = "\(self.finderTestDir)/\(fileName)-rw-test.dcm"

        Logger.info("#########################################################")
        Logger.info("# READ/WRITE INTEGRITY TEST")
        Logger.info("#")
        Logger.info("# Source file : \(path)")
        Logger.info("# Destination file : \(writePath)")
        Logger.info("#")

        if let dicomFile = DicomFile(forPath: path) {
            if printDatasets { Logger.info("\(dicomFile.dataset.description )") }

            Logger.info("# Read succeeded")

            if dicomFile.write(atPath: writePath) {
                Logger.info("# Write succeeded")
                Logger.info("#")

                let sourceFileSize = self.fileSize(filePath: path)
                let destFileSize = self.fileSize(filePath: writePath)
                let deviationPercents =
                    (Double(sourceFileSize) - Double(destFileSize)) / Double(sourceFileSize) * 100.0

                Logger.info("# Source file size : \(sourceFileSize) bytes")
                Logger.info("# Dest. file size  : \(destFileSize) bytes")

                if deviationPercents > 0.0 {
                    Logger.info("# Size deviation   : \(String(format:"%.8f", deviationPercents))%")
                }

                Logger.info("#")

                Logger.info("# Calculating checksum...")
                Logger.info("#")

                let originalSum = shell(launchPath: "/sbin/md5", arguments: ["-q", path])
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let savedSum = shell(launchPath: "/sbin/md5", arguments: ["-q", writePath])
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                Logger.info("# Source file MD5 : \(originalSum)")
                Logger.info("# Dest. file MD5  : \(savedSum)")
                Logger.info("#")

                if originalSum == savedSum {
                    Logger.info("# Checksum succeeded: \(originalSum) == \(savedSum)")
                } else {
                    Logger.info("# Error: wrong checksum: \(originalSum) != \(savedSum)")
                    Logger.info("#")
                    Logger.info("#########################################################")
                    return false
                }
            } else {
                Logger.info("# Error: while writing file: \(writePath)")
                Logger.info("#")
                Logger.info("#########################################################")
                return false
            }

            Logger.info("#")
            Logger.info("#########################################################")

            return true
        } else {
            Logger.info("# Error: cannot open file: \(writePath)")
            Logger.info("#")
            Logger.info("#########################################################")
            return false
        }
    }

    private func readFile(withPath path: String, checksum: Bool = true) -> Bool {
        let fileName = path.components(separatedBy: "/").last!.replacingOccurrences(
            of: ".dcm", with: "")
        let writePath = "\(self.finderTestDir)/\(fileName)-rw-test.dcm"

        Logger.info("#########################################################")
        Logger.info("# READ/WRITE INTEGRITY TEST")
        Logger.info("#")
        Logger.info("# Source file : \(path)")
        Logger.info("# Destination file : \(writePath)")
        Logger.info("#")

        if let dicomFile = DicomFile(forPath: path) {
            if printDatasets { Logger.info("\(dicomFile.dataset.description )") }

            Logger.info("# Read succeeded")
            Logger.info("#")

            if dicomFile.isCorrupted() {
                Logger.info("# WARNING : File is corrupted")
                Logger.info("#")
                return false
            }

            Logger.info("#########################################################")

            return true
        } else {
            Logger.info("# Error: cannot open file: \(writePath)")
            Logger.info("#")
            Logger.info("#########################################################")
            return false
        }
    }

    private func filePath(forName name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: name, ofType: "dcm")!

        return path
    }

    func fileSize(filePath: String) -> UInt64 {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: filePath)
            let dict = attr as NSDictionary

            return dict.fileSize()
        } catch {
            print("Error: \(error)")

            return 0
        }
    }

    public func shell(launchPath: String, arguments: [String]) -> String {
        #if os(macOS)
            let task = Process()
            task.launchPath = launchPath
            task.arguments = arguments

            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
                ?? ""
        #else
            Logger.warning("Shell commands are not supported on this platform.")
            return ""
        #endif
    }
    // Poulpy

    // RTDose tests

    public func testIsValid() {

        // TODO get files under RT folder, doesn't work atm; workaround, use filter to get "rt_" files
        var paths = Bundle.module.paths(forResourcesOfType: "dcm", inDirectory: nil)
        paths = paths.filter { $0.contains("rt_") }

        paths.forEach { path in
            if let dicomRT = DicomRT.init(forPath: path) {
                _ = Dose.isValid(dicomRT: dicomRT)
            }
        }

        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertTrue(Dose.isValid(dicomRT: dicomRT))
        }

        let path2 = Bundle.module.path(
            forResource: "rt_RTXPLAN.20110509.1010_Irregular", ofType: "dcm")
        guard let p2 = path2 else {
            return
        }

        if let dicomRT2 = DicomRT.init(forPath: p2) {
            XCTAssertFalse(Dose.isValid(dicomRT: dicomRT2))
        }
    }

    public func testGetDoseImageWidth() {

        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertEqual(Dose.getDoseImageWidth(dicomRT: dicomRT), 10)
        }
    }

    public func testGetDoseImageHeight() {
        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertEqual(Dose.getDoseImageHeight(dicomRT: dicomRT), 10)
        }
    }

    public func testToPNG() {
        // finderTestDir

        var paths = Bundle.module.paths(forResourcesOfType: "dcm", inDirectory: nil)
        paths = paths.filter { $0.contains("rt_") }

        paths.forEach { path in
            if let dcmFile = DicomFile(forPath: path) {
                if let dcmImage = DicomImage(dcmFile.dataset) {
                    dcmImage.toPNG(path: finderTestDir, baseName: dcmFile.fileName())
                }
            }

        }

        /*
        let path = Bundle.module.path(forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424", ofType: "dcm")
        if let p = path {

            if let dcmFile = DicomFile(forPath: p) {
                if let dcmImage = DicomImage(dcmFile.dataset) {
                    dcmImage.toPNG(path: finderTestDir, baseName: dcmFile.fileName())
                }
            }
        }
         */
    }

    public func testGetUnscaledDose() {
        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            // 0
            let unscaledDose = Dose.unscaledDose(dicomRT: dicomRT, row: 1, column: 1, frame: 1)
            XCTAssertNotNil(unscaledDose)
            if let dose = unscaledDose {
                XCTAssertTrue(dose is UInt32)
                XCTAssertEqual(dose as! UInt32, 0)
            }

            // 137984544
            let unscaledDose2 = Dose.unscaledDose(dicomRT: dicomRT, row: 5, column: 4, frame: 2)
            XCTAssertNotNil(unscaledDose2)
            if let dose = unscaledDose2 {
                XCTAssertTrue(dose is UInt32)
                XCTAssertEqual(dose as! UInt32, 137_984_544)
            }
        }
    }

    public func testGetDose() {
        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            // 0
            let dose = Dose.getDose(dicomRT: dicomRT, row: 1, column: 1, frame: 1)
            XCTAssertNotNil(dose)
            XCTAssertEqual(dose!, 0)

            let dose2 = Dose.getDose(dicomRT: dicomRT, row: 5, column: 4, frame: 2)
            XCTAssertNotNil(dose2)
            XCTAssertEqual(dose2!, 1.4865626863296)

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetDoseImage() {
        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            let r = Dose.getDoseImage(dicomRT: dicomRT, atFrame: 1)

            XCTAssert(!r.isEmpty)
        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetDoseImages() {
        let path = Bundle.module.path(
            forResource: "rt_dose_1.2.826.0.1.3680043.8.274.1.1.6549911257.77961.3133305374.424",
            ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            let r = Dose.getDoseImages(dicomRT: dicomRT)

            XCTAssert(!r.isEmpty)

        } else {
            Logger.error("no dicom file")
        }
    }

    // test Plan

    public func testGetToleranceTableItem() {
        // rt_RTXPLAN.20110509.1010_Irregular.dcm

        let path = Bundle.module.path(
            forResource: "rt_RTXPLAN.20110509.1010_Irregular.dcm", ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "ToleranceTableSequence", withNumber: "1"))
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "ToleranceTableSequence", withNumber: "2"))
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "ToleranceTableSequence", withNumber: "3"))

            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "ToleranceTableSequence", withNumber: "4"))

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetFractionGroupItem() {
        // rt_RTXPLAN.20110509.1010_Irregular.dcm

        let path = Bundle.module.path(
            forResource: "rt_RTXPLAN.20110509.1010_Irregular.dcm", ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "FractionGroupSequence", withNumber: "1"))

            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "FractionGroupSequence", withNumber: "2"))
            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "FractionGroupSequence", withNumber: "3"))
            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "FractionGroupSequence", withNumber: "4"))

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetBeamItem() {
        // rt_RTXPLAN.20110509.1010_Irregular.dcm

        let path = Bundle.module.path(
            forResource: "rt_RTXPLAN.20110509.1010_Irregular.dcm", ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "BeamSequence", withNumber: "1"))
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "BeamSequence", withNumber: "2"))
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "BeamSequence", withNumber: "3"))

            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "BeamSequence", withNumber: "4"))

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetPatientItem() {
        // rt_RTXPLAN.20110509.1010_Irregular.dcm

        let path = Bundle.module.path(
            forResource: "rt_RTXPLAN.20110509.1010_Irregular.dcm", ofType: "dcm")
        guard let p = path else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: p) {
            XCTAssertNotNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "PatientSetupSequence", withNumber: "1"))

            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "PatientSetupSequence", withNumber: "2"))
            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "PatientSetupSequence", withNumber: "3"))
            XCTAssertNil(
                Plan.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "PatientSetupSequence", withNumber: "4"))

        } else {
            Logger.error("no dicom file")
        }
    }

    // StructureSet

    public func testGetFrameOfReference() {
        // rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010

        guard
            let path = Bundle.module.path(
                forResource:
                    "rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010.dcm",
                ofType: "dcm")
        else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: path) {
            XCTAssertNotNil(
                StructureSet.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "ReferencedFrameofReferenceSequence",
                    withNumber: "1.2.840.113619.2.55.3.3767434740.12488.1173961280.931.803.0.11"))

            // replaced 1 by 0 at the end
            XCTAssertNil(
                StructureSet.getItemInSequenceForNumber(
                    dicomRT: dicomRT, forSequence: "PatientSetupSequence",
                    withNumber: "1.2.840.113619.2.55.3.3767434740.12488.1173961280.931.803.0.10"))

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetObservation() {
        // rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010

        guard
            let path = Bundle.module.path(
                forResource:
                    "rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010.dcm",
                ofType: "dcm")
        else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: path) {
            XCTAssertNotNil(StructureSet.getObservation(dicomRT: dicomRT, observationNumber: "1"))
            XCTAssertNotNil(StructureSet.getObservation(dicomRT: dicomRT, observationNumber: "2"))
            XCTAssertNotNil(StructureSet.getObservation(dicomRT: dicomRT, observationNumber: "3"))

            XCTAssertNil(StructureSet.getObservation(dicomRT: dicomRT, observationNumber: "10"))

        } else {
            Logger.error("no dicom file")
        }
    }

    public func testGetObservationByROINumber() {
        // rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010

        guard
            let path = Bundle.module.path(
                forResource:
                    "rt_RTSTRUCT.2.16.840.1.113669.2.931128.509887832.20120106104805.776010.dcm",
                ofType: "dcm")
        else {
            return
        }

        if let dicomRT = DicomRT.init(forPath: path) {
            XCTAssertNotNil(
                StructureSet.getObservationByROINumber(dicomRT: dicomRT, roiNumber: "1"))
            XCTAssertNotNil(
                StructureSet.getObservationByROINumber(dicomRT: dicomRT, roiNumber: "2"))
            XCTAssertNotNil(
                StructureSet.getObservationByROINumber(dicomRT: dicomRT, roiNumber: "3"))

            XCTAssertNil(StructureSet.getObservationByROINumber(dicomRT: dicomRT, roiNumber: "10"))

        } else {
            Logger.error("no dicom file")
        }
    }
}
