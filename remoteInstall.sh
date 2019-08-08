#!/bin/bash
curl -o doInstall.sh https://raw.githubusercontent.com/MTijbout/public/master/doInstall.sh
curl -o COL_TABLE https://raw.githubusercontent.com/MTijbout/public/master/COL_TABLE
chmod +x doInstall.sh
sudo ./doInstall.sh
rm doInstall.sh
rm COL_TABLE
echo -e "\n [i] log file can be found in /var/log/VMwarePulseAgentInstall-date_time ... \n"
