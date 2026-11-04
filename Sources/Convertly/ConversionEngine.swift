import Foundation
import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unsupportedInput(String), unsupportedConversion(String, String), unreadableFile, failedToCreateOutput, invalidData
    var errorDescription: String? {
        switch self {
        case .unsupportedInput(let ext): "The .\(ext) format is not supported."
        case .unsupportedConversion(let input, let output): "Conversion from .\(input) to .\(output) is not supported."
        case .unreadableFile: "The file could not be read."
        case .failedToCreateOutput: "The output file could not be created."
        case .invalidData: "The file does not contain valid data for this conversion."
        }
    }
}

enum ConversionEngine {
    static let supportedInputs: Set<String> = ["pdf", "md", "markdown", "txt", "text", "html", "htm", "jpg", "jpeg", "png", "heic", "heif", "csv"]

    static func supportedOutputs(for ext: String) -> [OutputFormat] {
        switch ext.lowercased() {
        case "pdf": [.md, .txt, .png, .jpg]
        case "md", "markdown": [.pdf, .txt, .html]
        case "txt", "text": [.pdf, .md, .html]
        case "html", "htm": [.txt, .md, .pdf]
        case "jpg", "jpeg": [.png, .pdf]
        case "png": [.jpg, .pdf]
        case "heic", "heif": [.jpg, .png]
        case "csv": [.pdf, .txt, .md, .html]
        default: []
        }
    }

    static func icon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": "doc.richtext"
        case "md", "markdown", "txt", "text": "doc.text"
        case "jpg", "jpeg", "png", "heic", "heif": "photo"
        case "csv": "tablecells"
        default: "doc"
        }
    }

    static func convert(_ input: URL, to format: OutputFormat, outputFolder: URL?) throws -> URL {
        let ext = input.pathExtension.lowercased()
        guard supportedInputs.contains(ext) else { throw ConversionError.unsupportedInput(ext) }
        guard supportedOutputs(for: ext).contains(format) else { throw ConversionError.unsupportedConversion(ext, format.rawValue) }
        let folder = outputFolder ?? input.deletingLastPathComponent().appendingPathComponent("Convertly", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = input.deletingPathExtension().lastPathComponent
        let output = uniqueURL(folder.appendingPathComponent(base).appendingPathExtension(format.rawValue))

        switch format {
        case .txt:
            try extractText(from: input, ext: ext).write(to: output, atomically: true, encoding: .utf8)
        case .md:
            let value = try extractText(from: input, ext: ext)
            let markdown = (ext == "html" || ext == "htm") ? htmlToText(value) : value
            try markdown.write(to: output, atomically: true, encoding: .utf8)
        case .html:
            let value = try extractText(from: input, ext: ext)
            let body = escapeHTML(value).replacingOccurrences(of: "\n", with: "<br>\n")
            let html = "<!doctype html><html><head><meta charset=\"utf-8\"><title>\(escapeHTML(base))</title></head><body><pre style=\"white-space:pre-wrap\">\(body)</pre></body></html>"
            try html.write(to: output, atomically: true, encoding: .utf8)
        case .pdf:
            if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) { try imageToPDF(input, output: output) }
            else { try textToPDF(try extractText(from: input, ext: ext), title: base, output: output) }
        case .png, .jpg:
            if ext == "pdf" { try pdfToImage(input, output: output, type: format == .png ? UTType.png : UTType.jpeg) }
            else { try convertImage(input, output: output, type: format == .png ? UTType.png : UTType.jpeg) }
        }
        return output
    }

    private static func extractText(from url: URL, ext: String) throws -> String {
        switch ext {
        case "pdf":
            guard let document = PDFDocument(url: url) else { throw ConversionError.unreadableFile }
            return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n\n")
        case "md", "markdown", "txt", "text", "html", "htm", "csv":
            return try String(contentsOf: url, encoding: .utf8)
        default:
            throw ConversionError.unsupportedInput(ext)
        }
    }

    private static func textToPDF(_ text: String, title: String, output: URL) throws {
        let pageSize = NSSize(width: 595, height: 842)
        let margin: CGFloat = 48
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 8
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black,
            .paragraphStyle: style
        ])
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ConversionError.failedToCreateOutput
        }
        var box = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (title as NSString).draw(at: NSPoint(x: margin, y: pageSize.height - margin - 24), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.black
        ])
        attributed.draw(in: NSRect(x: margin, y: margin, width: pageSize.width - 2 * margin, height: pageSize.height - 2 * margin - 40))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: output)
    }

    private static func pdfToImage(_ input: URL, output: URL, type: UTType) throws {
        guard let document = PDFDocument(url: input), let page = document.page(at: 0) else { throw ConversionError.unreadableFile }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = min(3, 2400 / max(bounds.width, bounds.height))
        let image = NSImage(size: NSSize(width: bounds.width * scale, height: bounds.height * scale))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
        if let context = NSGraphicsContext.current?.cgContext {
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
        }
        image.unlockFocus()
        try writeImage(image, output: output, type: type)
    }

    private static func convertImage(_ input: URL, output: URL, type: UTType) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.invalidData
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failedToCreateOutput }
    }

    private static func imageToPDF(_ input: URL, output: URL) throws {
        guard let image = NSImage(contentsOf: input) else { throw ConversionError.invalidData }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { throw ConversionError.invalidData }
        let document = PDFDocument()
        guard let page = PDFPage(image: NSImage(cgImage: cgImage, size: image.size)) else { throw ConversionError.failedToCreateOutput }
        document.insert(page, at: 0)
        guard document.write(to: output) else { throw ConversionError.failedToCreateOutput }
    }

    private static func writeImage(_ image: NSImage, output: URL, type: UTType) throws {
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.failedToCreateOutput
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failedToCreateOutput }
    }

    private static func htmlToText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func escapeHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func uniqueURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 2
        while true {
            let candidate = folder.appendingPathComponent("\(base) \(index)").appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
