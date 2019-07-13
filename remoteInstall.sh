#!/bin/bash
touch step1
curl -v -H "Cache-Control: no-cache" -o doInstall.sh https://raw.githubusercontent.com/MTijbout/public/master/doInstall.sh
chmod +x doInstall.sh
#sudo ./doInstall.sh