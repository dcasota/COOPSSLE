#!/bin/sh

rsynclogfile=$1
param1=$2
param2=$3
username=$4
password=$5

su $username --command="rsync -azuvWh -e \"ssh -o StrictHostKeyChecking=no\" $param1 $param2"


