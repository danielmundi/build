#!/bin/bash

./compile.sh 2>&1 | sudo tee output/debug/compile.log

echo
echo -------------------------------------------------------------
echo Those are possible failures in the build, please double check
echo -------------------------------------------------------------
grep -v -f .ignore-errors output/debug/compile.log | grep -A1 -iwn "error\|errors\|fail\|failure"

echo
echo -------------------------------------------------------------
echo Compilation logs are available on output/debug/compile.log
echo
echo If you want to ignore any errors, add the line to ignore
echo at file .ignore-errors
echo -------------------------------------------------------------
