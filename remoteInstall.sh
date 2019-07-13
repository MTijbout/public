#!/bin/bash
touch step1
curl -o doInstall.sh https://raw.githubusercontent.com/MTijbout/public/master/doInstall.sh
touch step2
chmod +x doInstall.sh
touch step3
sudo ./doInstall.sh
touch stepFinished
