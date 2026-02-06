# example

This is an example Flutter project demonstrating the Optical Character Recognition (OCR) feature of the Textify package. Textify is a basic text extraction library for clean digital images.

## Getting Started

This project serves as a starting point for using the OCR capabilities of the Textify package in your Flutter application. It showcases how to extract text from images using OCR and verify the results.

### Prerequisites

Before running this example, ensure you have the following installed:

- Flutter SDK (latest stable version recommended)
- Dart SDK
- An IDE (e.g., Android Studio, VS Code)

### Installation

1. Clone this repository or download the source code.
2. Open a terminal and navigate to the project directory.
3. Run the following command to get the required dependencies:
    ```bash
    flutter pub get
    ```

## Features Demonstrated

This example project showcases the following Textify OCR features:

- Extracting text from images
- Handling multiple font families

## Usage

To run the example app:

1. Ensure you have a device connected or an emulator running.
2. In the terminal, navigate to the project directory and run:
    ```bash
    flutter run
    ```

3. Explore the different screens and examples within the app to see Textify's OCR capabilities in action.

## Code Structure

- `lib/main.dart`: The entry point of the application.
- `lib/panel1_source/`: Image sources and generators for OCR inputs.
- `lib/panel2_steps/`: Step-by-step OCR processing views.
- `lib/panel3_results/`: Extracted text results and comparisons.
- `lib/widgets/`: Shared widgets used in the example app.

## Customization

Feel free to modify the example code to experiment with different Textify OCR features. The `pubspec.yaml` file includes the Textify package dependency, ensuring you have access to all its capabilities.

## Additional Resources

For more information on using Flutter and the Textify package:

- [Textify Package Documentation](https://pub.dev/packages/textify)
- [Flutter Documentation](https://docs.flutter.dev/)

## Troubleshooting

If you encounter any issues:

1. Ensure all dependencies are up to date.
2. Check that your Flutter environment is properly set up.
3. Consult the Textify documentation for specific package-related queries.

## Contributing

Contributions to improve this example are welcome. Please feel free to submit pull requests or create issues for bugs and feature requests.

## License

This example project is released under the MIT License. See the LICENSE file for details.
