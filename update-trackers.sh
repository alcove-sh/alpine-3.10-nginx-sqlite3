#!/bin/sh

TRACKER_LIST_BEST="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"
TRACKER_LIST_BEST_IP="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt"
TRACKER_LIST_NYAA="https://raw.githubusercontent.com/nyaadevs/nyaa/master/trackers.txt"


curl -sL "${TRACKER_LIST_BEST}" > trackers.txt
curl -sL "${TRACKER_LIST_BEST_IP}" >> trackers.txt
curl -sL "${TRACKER_LIST_NYAA}" >> trackers.txt

