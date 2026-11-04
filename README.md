# Convertly

A native macOS document and image converter, designed alongside [Rondel](https://github.com/thisulzen/rondel).

## Features
- Drag-and-drop or batch file selection
- Output format selector based on supported conversions
- Local conversions and selectable output folder
- Native SwiftUI interface using PDFKit, AppKit and ImageIO
- No cloud upload or telemetry

## Supported conversions
| Input | Output | Notes |
|---|---|---|
| PDF | TXT, Markdown, PNG, JPEG | Text extraction; image export renders the first page |
| Markdown | TXT, HTML, PDF | PDF uses a simple readable layout |
| TXT | Markdown, HTML, PDF | |
| HTML | TXT, Markdown, PDF | Basic HTML tag stripping for text export |
| JPEG / JPG | PNG, PDF | |
| PNG | JPEG, PDF | |
| HEIC / HEIF | JPEG, PNG | |
| CSV | TXT, Markdown, HTML, PDF | Retained as delimited text |

DOCX and XLSX workbook conversion are not included yet. Scanned PDFs require OCR. PDF-to-Markdown extracts text; it does not reconstruct the original layout.

## Build from source
Requires macOS 14+, Xcode 15+, Swift 5.9+.
```sh
swift build
swift test
swift run Convertly
```

## Install a prebuilt app
Open the latest GitHub Release and download `Convertly-macOS.zip`. Unzip it and move `Convertly.app` into Applications. This initial build is unsigned and not notarized; on first launch macOS may require right-click → Open.

## Privacy
All conversion happens locally on your Mac.