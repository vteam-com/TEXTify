#!/bin/sh
echo --- Analyze

dart analyze 
dart fix --apply

flutter analyze

dart format .

flutter test

tool/graph.sh
