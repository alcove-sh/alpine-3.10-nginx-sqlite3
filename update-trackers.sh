#!/bin/sh

TRACKER_LIST_BEST="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"
TRACKER_LIST_BEST_IP="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt"

wget -O - "${TRACKER_LIST_BEST}" > trackers.txt
wget -O - "${TRACKER_LIST_BEST_IP}" >> trackers.txt

