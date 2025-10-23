# Changelog

I will attempt to document all notable changes to this project in this file. I did not keep a changelog for pre-1.0 releases. Apologies.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [2.0.2] - 2025-10-23

### Fixed

- Use creatobject helper method when loading from files to prevent errors

## [2.0.1] - 2025-10-22

### Changed

- Small bug fixes and adjusts in logic

## [2.0.0] - 2025-10-22

### Changed

- Updated from PDFBox 2.0.30 to 3.0.6 (which involved some plumbing changes)

## [1.8.0] - 2025-03-11

- Method `drawRectangle()`

## [1.7.0] - 2024-01-04

### Added

- Method `splitPages()`

### Changed

- Updated from PDFBox 2.0.25 to 2.0.30

## [1.6.0] - 2022-03-10

### Fixed

- Fix `sanitize()` so it no longer fails on PDFs without a documentTree, metadata, etc.

## [1.5.1] - 2022-03-09

### Added

- Methods `getEmbeddedFiles()`, `hasEmbeddedSearchIndex()`, `getDocumentOutlineTitles()`, and `removeBookmarks()`
- More tests

### Changed

- Updated from PDFBox 2.0.19 to 2.0.25
- `sanitize()` now also removes the document outline (bookmarks)

## [1.1.0] - 2022-03-09

### Added

- Methods `getVersion()` and `getAcroForm()`
- TestBox as dev dependency
- Basic testing via TestBox in `/tests`
- `server.json` for testing
- `.gitignore`

## [1.0.0] - 2022-03-08

### Added

- A changelog
- Method `listXFAElements()`

### Changed

- When `getText()` encounters a PDF with issues that prevent text extraction, and error is logged but not thrown, and an empty string is returned. Resolves issue #2.
