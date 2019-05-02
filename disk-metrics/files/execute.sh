#!/bin/sh
dirname=$(echo `echo $(dirname "$0")`)
cd $dirname

echo "This is the script: execute" >> /tmp/campaign.log

## Create the folder for the scripts
DIRECTORY=/opt/scripts
if [ ! -d "$DIRECTORY" ]; then
    # Control will enter here if DIRECTORY NOT exists.
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Directory $DIRECTORY does not exists." >> /tmp/campaign.log
        sudo mkdir $DIRECTORY
        RESULT=$?
        if [ $RESULT -eq 0 ]; then
            echo "Directory $DIRECTORY created." >> /tmp/campaign.log 
        else 
        echo "Directory $DIRECTORY could not be created." >> /tmp/campaign.log
        fi
    else 
    echo "Directory $DIRECTORY exists." >> /tmp/campaign.log 
    fi

    ## Set rights on folder
    sudo chmod 777 $DIRECTORY
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Rights on directory $DIRECTORY set." >> /tmp/campaign.log
    else 
    echo "Rights on directory $DIRECTORY could not be set." >> /tmp/campaign.log
    fi  
fi

## Copy the files to the correct locations
sudo cp diskUtilization* $DIRECTORY
sudo chmod -R 777 $DIRECTORY
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "Copied the metrics generation files to $DIRECTORY" >> /tmp/campaign.log
else 
    echo "Could not copy files to directory $DIRECTORY " >> /tmp/campaign.log
fi

sudo cp gateway-metrics.service /etc/systemd/system
RRESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "Copied the service file to /etc/systemd/system" >> /tmp/campaign.log
else 
    echo "Could not copy service file to directory /etc/systemd/system" >> /tmp/campaign.log
fi

## Start and enable the service
sudo systemctl start gateway-metrics.service
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "Service gateway-metrics started successfully." >> /tmp/campaign.log
    sleep 2
    sudo systemctl enable gateway-metrics.service
    if [ $RESULT -eq 0 ]; then
        echo "Service gateway-metrics enabled successfully." >> /tmp/campaign.log
    else 
        echo "Could not enable gateway-metrics service." >> /tmp/campaign.log
    fi
    exit 0
else
    echo "Service gateway-metrics failed to start" >> /tmp/campaign.log
    exit 1
fi
