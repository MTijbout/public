#!/bin/bash
MAC=$(ifconfig | grep ether | tr -d ":" | awk '{print $2}')
HOSTNAME="$(uname -n)"
echo $HOSTNAME $MAC