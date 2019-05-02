#!/bin/bash

GWDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $1}' | awk -F '@' '{print $1}')

DISKUTILIZATION=$(/usr/bin/python3 /opt/scripts/diskUtilization.py)

sudo /opt/vmware/iotc-agent/bin/DefaultClient send-metric --device-id=$GWDEVICEID --name=Disk-Utilization --type=double --value=$DISKUTILIZATION

sleep 15