import XCTest
@testable import Convertly

final class ConversionEngineTests: XCTestCase {
    func testPDFOutputFormats() {
        XCTAssertEqual(Set(ConversionEngine.supportedOutputs(for: "pdf")), Set([.md, .txt, .png, .jpg]))
    }
    func testImageOutputFormats() {
        XCTAssertEqual(Set(ConversionEngine.supportedOutputs(for: "heic")), Set([.jpg, .png]))
        XCTAssertEqual(Set(ConversionEngine.supportedOutputs(for: "png")), Set([.jpg, .pdf]))
    }
    func testUnsupportedFormatsHaveNoOutputs() {
        XCTAssertTrue(ConversionEngine.supportedOutputs(for: "docx").isEmpty)
        XCTAssertTrue(ConversionEngine.supportedOutputs(for: "xlsx").isEmpty)
    }
}
