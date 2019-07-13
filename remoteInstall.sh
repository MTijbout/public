#!/bin/bash
touch step1
curl -v -o doInstall.sh https://raw.githubusercontent.com/MTijbout/public/master/doInstall.sh
chmod +x doInstall.sh
#sudo ./doInstall.sh