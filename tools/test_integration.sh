#!/bin/bash

flutter test --coverage --coverage-path=coverage/lcov.info || exit 1

genhtml --css-file coverage/genhtml.css  -q coverage/lcov.info -o coverage/html > coverage/cc.txt

# keep the file cc.txt in git log, but also display it to the user
cat coverage/cc.txt

open coverage/html/index.html