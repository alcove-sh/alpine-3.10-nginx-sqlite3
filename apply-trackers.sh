#!/bin/sh

TRACKER_LIST=`sed -n '/^#/d; /^ *$/d; p' trackers.txt | tr '\n' ','`

sed -i "s|^\(bt-tracker\)=.*|\1=${TRACKER_LIST}|g" "aria2.conf.example"

