<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

## 0.5.0 : 2025-12-27

### Breaking Changes

- Refactored Textify class to use TextifyConfig exclusively for configuration
- **Removed deprecated setters from Textify class**: `applyDictionary`, `excludeLongLines`, `dilatingSize`, and `innerSplit`. Use `TextifyConfig` instead when creating Textify instances.

### Updated

- sdk: ^3.10.0
- flutter: ">=3.38.5"
- Use the GLAD tool to generate the Layer Diagram

## 0.4.7 : 2025-10-16

### Changed

- Fix LINT warnings

## 0.4.6 : 2025-10-16

### Updated

- Dart: 3.9.2
- Flutter: 3.35.6

### Changed

- remove all "this."
- deprecated ".scale()"

## 0.4.5 : 2025-07-03

### Updated

- Dart: 3.8.1
- Flutter: 3.32.0
- flutter_lints: ^6.0.0

## 0.4.4 : 2025-04-22

### Updated

- add more English words
- Example: update package [pasteboard: ^0.4.0]

## 0.4.3 : 2025-04-07

### Added

- more API Documentation, PANA is now reporting 100% documentation coverage.

## 0.4.2 : 2025-04-06

### Added

- Example: Popup shoing detail of artifact
- 100% code coverage form tests

### Changed

- Improve character matching by matrix splitting when character matching score is low

## 0.4.1 : 2025-04-05

### Changed

- Improvement text matchings, now using average score of all templates fonts
- Code Coverage 99.3%
- Doc comments

## 0.4.0 : 2025-04-04

### Added

- Support for connected characters

### Changed

- Performance improvements
- Increased code coverage to 99.1%

## 0.3.4 : 2025-01-14

### Added

- 300 more English words to dictionary

### Fixed

- Dashboard "Apply Dictionary" functionality

## 0.3.3 : 2025-01-13

### Added

- New examples : "Simplified" and "Dashboard"

## 0.3.2 : 2025-01-09

### Changed

- Improved API documentation and comments in `correction.dart`

## 0.3.1 : 2025-01-09

### Changed

- Updated README.md to show examples of good clean vs problematic text in input images
- Improved example using the sample of "Good Clean Image"

## 0.3.0 : 2025-01-07

### Added

- Optional operation mode of AutoCorrection using English Dictionary and AutoCassing of words

### Changed

- Updated minimum SDK requirements : >=3.6.0, flutter : >=3.27.0

## 0.2.0 : 2024-12-16

### Changed

- Adjusted band tolerance to 50% (was 80%)
- Adjusted word gap to 50% (was 75%)
- Adjusted gray scale to 190 (was 128)
  
## 0.1.9 : 2024-12-15

### Added

- Unit test for converting PNG image to text

## 0.1.8 : 2024-12-15

### Changed

- Updated README.md
- Updated documentation in `band.dart` and `matrix.dart`

## 0.1.7 : 2024-12-14

### Changed

- Fixed deprecated warning for Flutter 3.27.0
- Updated packages

## 0.1.6 : 2024-10-13

### Changed

- Improved Band assignment of artifacts
- Major refactoring
  
## 0.1.5 : 2024-10-12

### Changed

- Updated Matrices.json to achieve 100% match for the 4 fonts at size 40
- Refactored and cleaned up code

## 0.1.4 : 2024-10-10

### Changed

- Removed `image_pipeline.dart`
- Renamed "Encloser" to "Enclosure"
  
## 0.1.3 : 2024-10-09

### Changed

- Updated README.md
- Updated Example/Dashboard

### Fixed

- Fixed enclosure count for 'R'

## 0.1.2 : 2024-10-08

### Added

- Support for characters : ! @ # & * - + = { } [ ] < > ?

## 0.1.1 : 2024-10-06

### Changed

- Used embedded fonts for generating template [Arial, Courier, Helvetica, Times New Roman]

## 0.1.0 : 2024-10-03

### Changed

- Removed unused functions
- Made functions private
- Documented code

## 0.0.9 : 2024-10-02

### Changed

- Refactored to handle Bands and detect spaces

## 0.0.8 : 2024-10-01

### Added

- Documented public API - Artifact, Band, CharacterDefinitions

## 0.0.7 : 2024-10-01

### Added

- Support for characters : $ ; \

### Changed

- Refactored to enable better editing of templates

## 0.0.6 : 2024-10-01

### Added

- Documented Matrix.dart

### Changed

- Performance improvement : avoid scoring the Artifact for space " "

### Fixed

- Bug in the Example:Edit Screen

## 0.0.5 : 2024-09-30

### Added

- New top-level API "String getTextFromImage(IMAGE)"

### Changed

- Ran `dart format .`

## 0.0.4 : 2024-09-30

### Added

- Linked package to GitHub repo : <https://github.com/vteam-com/textify>

## 0.0.3 : 2024-09-30

### Changed

- Updated README.md

## 0.0.2 : 2024-09-30

### Added

- Support for characters-allowed

### Changed

- Updated Example - When pasting, just show the resulting text

### Fixed

- Fixed many typos

## 0.0.1 : 2024-09-23

### Added

- Initial implementation
