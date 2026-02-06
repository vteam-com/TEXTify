#!/bin/sh

echo ↓------------------ Pub Get ------------------↓
flutter pub get > /dev/null
flutter pub upgrade > /dev/null

echo ↓------------------ Analyze ------------------↓
dart analyze > /dev/null
dart fix --apply
flutter analyze

echo ↓------------------ Format -------------------↓
dart format .

echo ↓------------------- Tests -------------------↓
flutter test

echo ↓------------------  Graph  ------------------↓
tool/graph.sh > /dev/null

#  ↓------------------  fCheck  ------------------↓
# Use an ephemeral private directory for this session's fcheck installation
# (avoid contaminating the user's global pub cache and avoid version conflicts)
mkdir -p "$PWD/.dart_tool/fcheck_pub_cache"
export PUB_CACHE="$PWD/.dart_tool/fcheck_pub_cache"

# Install the pinned version into the isolated cache, then run it.
# Note: `dart pub cache exec` doesn't exist on all Dart SDK versions; `pub global run` does.
dart pub global activate fcheck 0.8.5 > /dev/null

dart pub global run fcheck --svg --svgfolder --fix

#  ↓------------------  Log result %  ------------------↓
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr '.' '_')
TEXTIFY_TEST_VERBOSE=1 flutter test test/ocr_eval_test.dart -r expanded \
  > ./test/test_results_$VERSION.txt
