#!/bin/sh

TRACKER_LIST=`sed -n '/^#/d; /^ *$/d; p' trackers.txt`
TRACKER_LIST=`echo -n "${TRACKER_LIST}" | tr '\n' ','`

sed -i "s|^\(bt-tracker\)=.*|\1=${TRACKER_LIST}|g" "aria2.conf.example"

