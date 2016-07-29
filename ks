#!/bin/bash

pid=$(ps -u | grep shell | awk '{print$2; exit}' )
cntr=10
while [ $cntr -gt 0 ]
do
  kill -9 $pid
  pid=$(ps -u | grep shell | awk '{print$2; exit}' )
  let cntr=cntr-1
done
