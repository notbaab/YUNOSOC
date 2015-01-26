#!/bin/bash
rm tmpRC.txt tmpRef.txt

echo "Reference run"
testrunner_client tests/$1 >> tmpRef.txt 

echo "Our compiler"

./RCdbg tests/$1 >> tmpRC.txt 

vimdiff tmpRC.txt tmpRef.txt 
