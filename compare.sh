#!/bin/bash
rm tmpRC.txt tmpRef.txt

echo "Reference run"
testrunner_client project2/tests/$1 &> /dev/null 
make compile
./a.out >> tmpRef.txt

echo "Our compiler"

./RC project2/tests/$1 &> /dev/null
make compile
./a.out >> tmpRC.txt 

vimdiff tmpRC.txt tmpRef.txt 
