# Textify

Textify is a Flutter package designed to extract text from clean digital images with standard fonts. It is 100% cross-platform, utilizing native Dart and Flutter code, and works offline without any package dependencies.

## Features

- Extracts text from clean digital images
- Supports standard fonts like Arial, Helvetica, Times New Roman, and Courier
- Fully cross-platform
- Pure Dart and Flutter implementation
- Offline functionality
- No external package dependencies

## Why Textify?

Textify addresses common limitations of existing OCR (Optical Character Recognition) solutions:

1. Lightweight: Most OCR libraries are heavy and often rely on external system dependencies or remote cloud services, complicating deployment and increasing costs.

2. Simplified Setup: Popular solutions like Tesseract require complex build configurations, including C/C++ compilation, which can be difficult to manage across platforms.

3. Web Compatibility: Many OCR solutions do not support Flutter web clients, limiting their cross-platform usability.

Textify overcomes these issues with a lightweight, pure Dart implementation that works seamlessly across all Flutter platforms, including web, without external dependencies.

## Limitations and Requirements

While Textify offers significant advantages, it's essential to understand its limitations:

- Optimized for clean digital images with standard fonts.
- May struggle with complex layouts or handwritten text.
- For advanced OCR needs, consider other solutions.

### Requirements for Optimal Performance

- Clean, computer-generated documents
- Minimal background noise (e.g., no watermarks)
- High contrast between text and background
- No handwritten or italic text
- Isolated characters (not touching other artifacts)

## Getting Started

To install Textify, add it to your pubspec.yaml file:

dependencies:
  textify: ^latest_version

Then run:

flutter pub get

## Usage

Here's a basic example of how to use Textify:

```dart
import 'package:textify/textify.dart';

void main() async {
  final textify = Textify();
  await textify.init();

  final image = // Load your image here
  final extractedText = await textify.getTextFromImage(image);

  print(extractedText);
}
```

Please contribute and report issues on the GitHub repository.
<https://github.com/vteam-com/textify>
