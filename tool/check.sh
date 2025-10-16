#!/bin/sh
echo --- Pub Get
flutter pub get
flutter pub upgrade

echo --- Analyze

dart analyze 
dart fix --apply

flutter analyze

dart format .

flutter test

tools/graph.sh
