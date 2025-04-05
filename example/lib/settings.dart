import 'package:shared_preferences/shared_preferences.dart';

/// Manages the application settings, including user preferences stored in SharedPreferences.
class Settings {
  bool isExpandedArtifactFound = true;
  bool isExpandedResults = true;
  bool isExpandedSource = true;
  bool applyDictionary = false;

  /// Loads the application settings from the device's SharedPreferences.
  /// This method reads the stored values for various settings, such as
  /// whether certain UI elements should be expanded, and whether the
  /// dictionary should be applied. If no stored value is found, the
  /// method uses default values.
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    isExpandedSource = prefs.getBool('expanded_source') ?? true;
    isExpandedArtifactFound = prefs.getBool('expanded_found') ?? true;
    isExpandedResults = prefs.getBool('expanded_results') ?? true;
    applyDictionary = prefs.getBool('apply_dictionary') ?? false;
  }

  /// Saves the application settings to the device's SharedPreferences.
  /// This method writes the current values of various settings, such as
  /// whether certain UI elements should be expanded, and whether the
  /// dictionary should be applied, to the device's SharedPreferences.
  Future<void> save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool('expanded_source', isExpandedSource);
    await prefs.setBool('expanded_found', isExpandedArtifactFound);
    await prefs.setBool('expanded_results', isExpandedResults);
    await prefs.setBool('apply_dictionary', applyDictionary);
  }
}
