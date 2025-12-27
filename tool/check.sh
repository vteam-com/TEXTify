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
