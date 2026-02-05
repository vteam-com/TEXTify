#!/bin/sh

echo ↓------------------ Pub Get ------------------↓
flutter pub get
flutter pub upgrade

echo ↓------------------ Analyze ------------------↓
dart analyze 
dart fix --apply
flutter analyze

echo ↓------------------ Format ------------------↓
dart format .

echo ↓------------------ Tests ------------------↓
flutter test

echo ↓------------------  Graph  ------------------↓
tool/graph.sh

echo ↓------------------  fCheck  ------------------↓
# Use an ephemeral private directory for this session's fcheck installation
# (avoid contaminating the user's global pub cache and avoid version conflicts)
mkdir -p "$PWD/.dart_tool/fcheck_pub_cache"
export PUB_CACHE="$PWD/.dart_tool/fcheck_pub_cache"

# Install the pinned version into the isolated cache, then run it.
# Note: `dart pub cache exec` doesn't exist on all Dart SDK versions; `pub global run` does.
dart pub global activate fcheck 0.8.3 > /dev/null

dart pub global run fcheck --svg --svgfolder
