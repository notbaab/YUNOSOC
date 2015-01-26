#!/bin/bash
echo "Reference run"
testrunner_client tests/$1

echo "Our compiler"

./RC tests/$1

