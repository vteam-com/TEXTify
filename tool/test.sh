#!/bin/bash
set -e

flutter test --coverage --coverage-path=coverage/lcov.info > /tmp/textify_test_output.txt 2>&1
test_exit=$?

# Show pass/fail summary
grep -E "All tests passed|Some tests failed|FAILED" /tmp/textify_test_output.txt || true

if [ $test_exit -ne 0 ]; then
  # On failure, show full output for debugging
  cat /tmp/textify_test_output.txt
  exit $test_exit
fi

grep -E "OCR eval \(dict:(off|on) *\):" /tmp/textify_test_output.txt \
  | sed -E 's/^.*(OCR eval \(dict:(off|on) *\):.*)$/\1/' || true
echo "Coverage: $(lcov --summary coverage/lcov.info 2>&1 | grep 'lines' | sed 's/.*lines[.:]*  *//')"
