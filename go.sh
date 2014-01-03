#!/bin/bash

make clean;
make
rm fuckups;

for a in {1..30}
do
  echo "######################## TEST RESU "$a" ####################" >> fuckups
  ./runme <test/test"$a".in  >resu
  diff resu test/test"$a".out  >> fuckups
done

