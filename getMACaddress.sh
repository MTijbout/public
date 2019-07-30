#!/usr/bin/env bash
MAC=$(ifconfig | grep ether | tr -d ":" | awk '{print $2}')
HOSTNAME="$(uname -n)"
IPaddr="$(hostname -I)"
echo $HOSTNAME $MAC $IPaddr
