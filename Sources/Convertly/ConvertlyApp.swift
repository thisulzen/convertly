import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct ConvertlyApp: App {
    var body: some Scene {
        WindowGroup {
            ConverterView().frame(minWidth: 760, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ConverterView: View {
    @State private var files: [URL] = []
    @State private var outputFormat: OutputFormat = .pdf
    @State private var outputFolder: URL?
    @State private var pickingFiles = false
    @State private var pickingFolder = false
    @State private var converting = false
    @State private var status = "Drop files here to get started"
    @State private var results: [ConversionResult] = []
    @State private var dragActive = false

    private var availableFormats: [OutputFormat] {
        let extensions = Set(files.map { $0.pathExtension.lowercased() })
        guard !extensions.isEmpty else { return OutputFormat.allCases }
        let supported = extensions.reduce(into: Set<String>()) { partial, ext in
            partial.formUnion(ConversionEngine.supportedOutputs(for: ext).map(\.rawValue))
        }
        return OutputFormat.allCases.filter { supported.contains($0.rawValue) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            HStack(alignment: .top, spacing: 22) {
                mainColumn
                sidePanel.frame(width: 235)
            }.padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(isPresented: $pickingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): addFiles(urls)
            case .failure(let error): status = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { outputFolder = urls.first }
        }
        .onChange(of: availableFormats) { _, formats in
            if !formats.contains(outputFormat), let first = formats.first { outputFormat = first }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.13))
                Image(systemName: "doc.zipper").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.accentColor)
            }.frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Convertly").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Documents and images, converted locally").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { pickingFiles = true } label: {
                Label("Add files", systemImage: "plus").font(.system(size: 13, weight: .semibold))
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(.horizontal, 24).padding(.vertical, 20)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Convert files").font(.system(size: 18, weight: .semibold))
                Text("Choose one or more files, then pick the output format.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            dropZone
            if !files.isEmpty {
                HStack {
                    Text("\(files.count) file\(files.count == 1 ? "" : "s") selected").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Clear") { files.removeAll(); results.removeAll(); status = "Drop files here to get started" }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(files, id: \.absoluteString) { file in fileRow(file) }
                    }
                }.frame(maxHeight: 185)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("OUTPUT FORMAT").font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                    ForEach(availableFormats) { format in
                        Button { outputFormat = format } label: {
                            VStack(spacing: 6) {
                                Image(systemName: format.symbol).font(.system(size: 18))
                                Text(format.rawValue.uppercased()).font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).frame(height: 62)
                            .background(outputFormat == format ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.035))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(outputFormat == format ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: outputFormat == format ? 1.5 : 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(files.isEmpty)
                    }
                }
                Text(outputFormat.description).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT RESULTS").font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
                    ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .orange)
                            Text(result.message).font(.system(size: 11)).lineLimit(2)
                        }
                    }
                }
            }
            HStack {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button { convertFiles() } label: {
                    if converting {
                        ProgressView().controlSize(.small)
                        Text("Converting…")
                    } else {
                        Label("Convert \(files.isEmpty ? "" : "\(files.count)")", systemImage: "arrow.right.circle.fill")
                    }
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(files.isEmpty || converting || !availableFormats.contains(outputFormat))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 30, weight: .light)).foregroundStyle(Color.accentColor)
            Text("Drop your files here").font(.system(size: 15, weight: .semibold))
            Text("PDF, Markdown, text, images and CSV").font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Browse files…") { pickingFiles = true }.buttonStyle(.bordered).controlSize(.small)
        }
        .frame(maxWidth: .infinity).frame(height: 158)
        .background(dragActive ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.025))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])).foregroundStyle(dragActive ? Color.accentColor : Color.primary.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onDrop(of: [.fileURL], isTargeted: $dragActive) { providers in
            let group = DispatchGroup()
            let lock = NSLock()
            var urls: [URL] = []
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        lock.lock(); urls.append(url); lock.unlock()
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) { addFiles(urls) }
            return true
        }
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ConversionEngine.icon(for: url.pathExtension)).font(.system(size: 17)).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(url.pathExtension.uppercased() + " · " + url.deletingLastPathComponent().lastPathComponent)
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { files.removeAll { $0 == url } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }.buttonStyle(.plain)
        }.padding(10).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Output location").font(.system(size: 14, weight: .semibold))
                HStack(spacing: 8) {
                    Image(systemName: "folder").font(.system(size: 18)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(outputFolder?.lastPathComponent ?? "Near original files").font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(outputFolder?.path ?? "A Convertly folder is created").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Button("Choose folder…") { pickingFolder = true }.buttonStyle(.bordered).controlSize(.small)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                Text("How it works").font(.system(size: 14, weight: .semibold))
                feature("lock.shield", "Local and private", "Files stay on your Mac.")
                feature("square.stack.3d.up", "Batch conversion", "Convert multiple files at once.")
                feature("keyboard", "Simple workflow", "Clear formats and useful feedback.")
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
            Text("Convertly  ·  macOS 14+").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addFiles(_ urls: [URL]) {
        let accepted = urls.filter { ConversionEngine.supportedInputs.contains($0.pathExtension.lowercased()) }
        for url in accepted where !files.contains(url) { files.append(url) }
        if accepted.isEmpty { status = "No supported file types were selected." }
        else { status = "Ready to convert \(files.count) file(s)." }
    }

    private func convertFiles() {
        guard !files.isEmpty else { return }
        converting = true
        results = []
        let inputFiles = files
        let format = outputFormat
        let folder = outputFolder
        Task.detached {
            var completed: [ConversionResult] = []
            for file in inputFiles {
                do {
                    let output = try ConversionEngine.convert(file, to: format, outputFolder: folder)
                    completed.append(.init(success: true, message: "\(file.lastPathComponent) → \(output.lastPathComponent)"))
                } catch {
                    completed.append(.init(success: false, message: "\(file.lastPathComponent): \(error.localizedDescription)"))
                }
            }
            let finalResults = completed
            await MainActor.run {
                results = finalResults
                let successes = finalResults.filter(\.success).count
                status = "\(successes) of \(finalResults.count) file(s) converted."
                converting = false
            }
        }
    }
}

struct ConversionResult {
    let success: Bool
    let message: String
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case pdf, md, txt, html, png, jpg
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pdf: "doc.richtext"
        case .md: "text.alignleft"
        case .txt: "doc.plaintext"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .png, .jpg: "photo"
        }
    }
    var description: String {
        switch self {
        case .pdf: "Create a clean PDF from text, CSV, or an image."
        case .md: "Export text or PDF text content to Markdown."
        case .txt: "Extract plain text from supported documents."
        case .html: "Create a lightweight HTML document from text or Markdown."
        case .png: "Convert supported image formats or render the first PDF page."
        case .jpg: "Convert supported images to JPEG or render the first PDF page."
        }
    }
}
