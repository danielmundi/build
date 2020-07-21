#!/bin/bash

./compile.sh $@

errors=$(grep -v -f .ignore-errors output/debug/wp-compile.log |
	    grep --color=always -A1 -iwn "error\|errors\|fail\|failure\|operation not permitted\|permission denied\|unable to locate\|could not connect to\|read-only file system\|connection refused\|fatal\|unable")

echo

if [ -n "$errors" ]; then
  echo -e "\e[0;33m"
  echo --------------------------------------------------------------
  echo Those are possible failures in the build, please double check
  echo --------------------------------------------------------------
  echo -e "\x1B[0m"

  echo "$errors"

  echo
  echo --------------------------------------------------------------
  echo Compilation logs are available on output/debug/wp-compile.log
  echo
  echo If you want to ignore any errors, add the line to ignore
  echo at file .ignore-errors
  echo --------------------------------------------------------------
else
  echo --------------------------------------------------------------
  echo -e "[\e[0;32m Success! \x1B[0m] No obvious errors found while building"
  echo
  echo You can check compilation logs at output/debug/wp-compile.log
  echo --------------------------------------------------------------
fi
