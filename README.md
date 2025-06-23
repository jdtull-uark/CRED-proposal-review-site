# nsfproposalhelper_app

A Flutter web app for reviewing NSF proposals by flagging and highlighting specific terms in PDF documents.

## Features

- Upload a PDF proposal for review.
- Optionally upload a CSV/XLSX file with custom terms to flag.
- Automatically detects and highlights flagged terms in the PDF.
- Displays a summary of flagged terms, including counts and page numbers.
- Interactive tree view to jump to flagged terms in the PDF.
- Download the highlighted PDF.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Dart SDK (comes with Flutter)
- For desktop: [Flutter desktop support](https://docs.flutter.dev/desktop)

## Usage

1. Click "Upload PDF" to select a proposal PDF.
2. (Optional) Click "Upload CSV (optional)" to provide a list of custom terms.
3. Click "Review" to analyze the document.
4. View flagged terms in the sidebar and click to jump to their locations in the PDF.
5. Download the highlighted PDF using the provided button.

## Dependencies

- [fluent_ui](https://pub.dev/packages/fluent_ui)
- [file_picker](https://pub.dev/packages/file_picker)
- [pdfrx](https://pub.dev/packages/pdfrx)
- [logger](https://pub.dev/packages/logger)
- [http](https://pub.dev/packages/http)
- [two_dimensional_scrollables](https://pub.dev/packages/two_dimensional_scrollables)
- [universal_html](https://pub.dev/packages/universal_html)
- [fluentui_system_icons](https://pub.dev/packages/fluentui_system_icons)

## Project Structure

- `lib/main.dart` – Main application logic and UI.
- `assets/` – App images and icons.
- `web/` – Web-specific files.
- `linux/`, `windows/`, `macos/` – Desktop platform files.

## API

This app communicates with a backend service for term flagging and PDF highlighting:
- `https://nsf-language-reviewer.onrender.com/flag-terms/`
- `https://nsf-language-reviewer.onrender.com/highlight-terms/`

## License

MIT License (or specify your license here)

---

*This project is not affiliated with the National Science Foundation.*