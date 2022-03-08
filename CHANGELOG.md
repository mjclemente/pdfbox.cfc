# Changelog

I will attempt to document all notable changes to this project in this file. I did not keep a changelog for pre-1.0 releases. Apologies.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.0.0] - 2022-03-08

### Added

- A changelog
- Method `listXFAElements()`

### Changed

- When `getText()` encounters a PDF with issues that prevent text extraction, and error is logged but not thrown, and an empty string is returned. Resolves issue #2.
