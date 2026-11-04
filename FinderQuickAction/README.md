# Convertly Finder Quick Action

Adds **Quick Actions → Convert with Convertly** to Finder without requiring the Convertly GUI app.

## Install
1. Download or clone this repository on your Mac.
2. Open Terminal in the repository folder.
3. Run:
   ```sh
   chmod +x FinderQuickAction/*.sh
   ./FinderQuickAction/install-finder-quick-action.sh
   ```
4. In Finder, right-click a file and choose **Quick Actions → Convert with Convertly**.

The installer creates a small Automator workflow in your user Services folder. It is not a standalone GUI app.

## Supported by this lightweight action
- JPEG / PNG / HEIC image conversions to PNG or JPEG
- PNG / JPEG to PDF
- Some TXT / RTF / HTML / DOC / DOCX / ODT conversions using macOS `textutil`

PDF-to-Markdown/text extraction, OCR and Excel workbook conversion are not implemented in this lightweight Finder action yet. Conversions run locally; output files are saved beside the source.
