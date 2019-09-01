# Changelog
All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
### Added
- Settings page added to the dashboard.
  - Organizational settings to be saved and cached (requires restart).
  - Multiple user passwords can be saved, when a username is passed as a parameter, it will look up stored credentials.
    - Warning: CONTENTdm Tools is designed for single-workstation use by a single user. Only allow multiple users to store credentials in a trusted environment.
- Parallel processing for Batch Create and Batch OCR.
  - Downloading images.
  - Converting images for OCR.
  - Running OCR.
- IIIF download method for Batch OCR. (Monograph compound-objects not supported at this time.)
- Collection metadata export (tab-delimited text), unlock collection metadata, index collection metadata features added to the dashboard.
  - CONTENTdm credentials must be stored for user to export metadata.
- PDFtk and xpdf utilities added.
  - Text can now be extracted from existing searchable PDFs if included in object folders rather than running OCR.
- Verbose logging and help text added to scripts and functions. Progress indicators, where possible, for parallel actions.
### Changed
- Organizational settings and user credentials are now saved in a CSV and managed through dashboard GUI with CLI fallback. Passwords are stored as secure strings.
- Normal field names can now be used for batch edits, CONTENTdm Tools will map field names to field nicknames automatically.
- Batch OCR uses throttled downloads for collections with over 200 images to download.
- OCR text now preserves line breaks, but removes duplicate line breaks.
- "Start Batches" on navigation menu now just called "Batches".
- Collection and field lookups moved into a single UI row.
- Updated documentation.
- Moved logic for various activities into external functions for reuse.
- Metadata processing will now automatically add `File Name` field if not included and make sure it's the last column if it's included.
- Improved error handling and QC reporting.
- Batches from the dashboard now start in PowerShell window using `-ExecutionPolicy Bypass`.
### Removed

## [1.0.0](https://github.com/psu-libraries/contentdmtools/releases/tag/v1.0) - 2019-08-06
### Added
- Batch create compound objects from TIF images, including OCR text and searchable PDFs, with full compound-object tab-d metadata in directory structure.
- Batch OCR/Re-OCR a collection.
- Batch editing of metadata.
- Collection and collection field property lookups.
- Web-based dashboard GUI.
- Individual user credential management via CLI.
- Documentation.

### Changed

### Removed

[Unreleased]: https://github.com/psu-libraries/contentdmtools/compare/v1.0...HEAD
[1.0.0]: https://github.com/olivierlacan/keep-a-changelog/compare/v0.3.0...v1.0.0
[1.0.0]: https://github.com/psu-libraries/contentdmtools/releases/tag/v1.0