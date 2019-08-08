#!/bin/bash

################################################################################
#                            - INITIAL ROUTINES -                              #
################################################################################

## Version of theScript.sh
SCRIPT_VERSION="0.7"
WORKDIR=/$PWD
SCRIPT_NAME="VMwarePulseAgentInstall"

## Log file definition
LOGFILE=$WORKDIR/$SCRIPT_NAME-`date +%Y-%m-%d_%Hh%Mm`.log

## Logging and ECHO functionality combined.
printl() {
    printf "\n%s" "$1"
    echo -e "$1" >> $LOGFILE
}

printl "  ${INFO} Installation of VMware Pulse Agent."
printl "  ${INFO} Connection initiated from: $SSH_CLIENT"
printl "  ${INFO} Script version: $SCRIPT_VERSION"

## Determine CPU Architecture:
CPUARCH=$(lscpu | grep Architecture | tr -d ":" | awk '{print $2}')
printl "  ${INFO} CPU Architecture detected: $CPUARCH"

################################################################################
# Install the VMware Pulse Agent.
################################################################################

## Module Functions

## Auto - Is installed or not.
pulseAgentAlreadyInstalled() {
    printl "  ${INFO} Pulse Agent: Check if already installed."
    ## Check if the pulse agent is already installed.
    if [ ! -f /opt/vmware/iotc-agent/version ]; then
        printl "  ${CROSS} Pulse Agent: Not installed."
        PLSAGTINSTALLED="false"
    else
        printl "  ${TICK} Pulse Agent: Is installed."
        PLSAGTINSTALLED="true" 
    fi
}

pulseAgentResinstall() {
    printl "  - Pulse Agent: Check to reinstall the Pulse Agent."
    if (whiptail --title "Pulse Agent Installed" --yesno "Pulse agent is already installed. Reinstall?\nOK?" 8 78); then
        ## Reinstall the agent.
        printl "    - Pulse Agent: Selection to reinstall the agent."
        PLSAGTREINSTALL="true"
    else
        ## User does not want to reinstall the agent when it is already installed.
        printl "    - Pulse Agent: Selection NOT to reinstall the agent."
        PLSAGTREINSTALL="false"
        return
    fi
}

## Auto - Instance Hardcoded
getPulseInstanceDetails() {
    printl "  - Pulse Agent: Collect required environment details."
    ## Collect details of the targeted Pulse environment.
    # PULSEINSTANCE="iotc005"
    # PULSEINSTANCE=$(whiptail --inputbox "\nEnter your Pulse Console Instance\n(for example iotc001,iotc002, etc.):\n" --title "Installation Pulse Agent" 10 60 $PULSEINSTANCE 3>&1 1>&2 2>&3)
    PULSEADDENDUM=".vmware.com"
    printl "    - Pulse instance: $PULSEINSTANCE"
    PULSEHOST="$PULSEINSTANCE$PULSEADDENDUM"
    printl "    - Pulse host: $PULSEHOST"
    PULSEPORT=443
    TIMEOUT=1
}

## Auto - Check Connection
testPulseInstanceConnectivity(){
    ## TEST CONNECTION TO YOUR PULSE INSTANCE"
    printl "  ${INFO} Pulse Agent: Test connection to Pulse Instance: $PULSEHOST"
    if [[ $OPSYS == *"CENTOS"* ]]; then
        ## Install nc if not present.
        [ ! -x /bin/nc ] && $PCKMGR $AQUIET -y update > /dev/null 2>&1 && $PCKMGR $AQUIET -y install nc 2>&1 | tee -a $LOGFILE
    fi

    if nc -w $TIMEOUT -z $PULSEHOST $PULSEPORT; then
        printl "  ${TICK} Connection to the Pulse Server ${PULSEHOST} was Successful"
    else
        printl "  ${CROSS} CONNECTION FAILED!"
        printl "  ${ESCL} - Connection to the Pulse Server ${PULSEHOST} Failed"
        printl "  ${ESCL} - Please Confirm if the Pulse URL is correct"
        printl "  ${ESCL} - If the Pulse URL is correct, then please ensure that we can open an outbound HTTPS connection to the Pulse Server over port 443"
        return
    fi
}

## Auto - Get latest version for download.
getPulseAgentLatestVersionInfo() {
    ## Determine agent version to be downloaded.
    printl "  ${INFO} Pulse Agent: Get information on latest Pulse Agent available."
    PULSE_MANIFEST="https://$PULSEINSTANCE.vmware.com/api/iotc-agent/manifest.json"
    printl "  ${INFO} - Manifest file: $PULSE_MANIFEST"
    printl "  ${INFO} - Download folder: $PLSAGTDLFLD"
    printl "  ${INFO} - Manifest file: $PLSAGTDLFLD/manifest.json"
    printl ""
    printl ""
    curl -o $PLSAGTDLFLD/manifest.json $PULSE_MANIFEST 2>&1 | tee -a $LOGFILE
    if [ $? -eq 0 ]; then
        printl "  ${TICK} - Pulse Agent: Manifest download successful."
    else
        printl "  ${CROSS} - Pulse Agent: Manifest download NOT successful."
    fi
    PLSAGTVERSION=$(awk -F'"' '{print $8}' $PLSAGTDLFLD/manifest.json)
    printl "  ${INFO} - Pulse Agent: Available for download: $PLSAGTVERSION "
}

# compareLatestPulseAgentVersion() {
#     printl "  ${INFO} Pulse Agent: Compare the versions."
#     PLSAGTINSTALLVER=$(cat /opt/vmware/iotc-agent/version)
#     printl "  ${INFO} - Installed version: $PLSAGTINSTALLVER"
#     if [ -z "$PLSAGTINSTALLVER" ]; then
#         ## There is no value in variable.
#         printl "  ${CROSS} ERROR: Empty variable. Cannot proceed."
#         return
#     else
#         printl "  ${INFO} - Available version: $PLSAGTVERSION"
#         if [[ "$PLSAGTINSTALLVER" == "$PLSAGTVERSION" ]]; then
#             PLSAGTLATEST="true"
#             printl "  ${TICK} - Latest version is installed."
#         else
#             PLSAGTLATEST="false"
#             printl "  ${ESCL} - Older version installed: $PLSAGTINSTALLVER"
#         fi
#     fi
# }

subDownloadPulseAgent() {
    ## Downloading the agent.
    printl "  ${INFO}  Pulse Agent: Downloading the Pulse Agent.\N"
    curl -o $PLSAGTDLFLD/$1 $2 2>&1 | tee -a $LOGFILE
    if [ $? -eq 0 ]; then
        printl "  ${TICK} - Pulse Agent: Download successful."
        ## Unpacking the agent.
        printl "  ${INFO} - Unpack $PLSAGTDLFLD/$1"
        tar -xzf $PLSAGTDLFLD/$1 -C $PLSAGTDLFLD/
        printl "  ${INFO} - Pulse Agent for $3 is unpacked."  
    else 
        printl "  ${CROSS} - Pulse Agent: Download NOT successful."
    fi
}

## Auto - Download
doPulseAgentDownload() {
    printl "  ${INFO} - Pulse Agent: Initiating download."
    PULSEAGENTX86="iotc-agent-x86_64-$PLSAGTVERSION.tar.gz"
    PULSEAGENTARM="iotc-agent-arm-$PLSAGTVERSION.tar.gz"
    PULSEAGENTARM64="iotc-agent-aarch64-$PLSAGTVERSION.tar.gz"
    PULSEURLX86="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTX86"
    PULSEURLARM="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTARM"
    PULSEURLARM64="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTARM64"

    if [[ $CPUARCH == *"x86_64"* ]];then
        subDownloadPulseAgent "$PULSEAGENTX86" "$PULSEURLX86" "$CPUARCH"  
        elif [[ $CPUARCH == *"armv7l"* ]];then
            subDownloadPulseAgent "$PULSEAGENTARM" "$PULSEURLARM" "$CPUARCH"      
        elif [[ $CPUARCH == *"ARMv8"* ]];then
            subDownloadPulseAgent "$PULSEAGENTARM64" "$PULSEURLARM64" "$CPUARCH" 
        elif [[ $CPUARCH == *"i686"* ]];then
            printl "  ${CROSS} By the look of it, $CPUARCH is not one of the supported CPU Architectures - aborting${BIWhite}\r\n"; exit
        else
            printl "  ${CROSS} By the look of it, $CPUARCH is not one of the supported CPU Architectures - aborting${BIWhite}\r\n"; exit
    fi

    ## Set permissions
    chmod 777 $PLSAGTDLFLD/iotc-agent/install.sh
    chmod 777 $PLSAGTDLFLD/iotc-agent/uninstall.sh
}

## Auto - Install
doPulseAgentInstall() {
    ## Installing the agent
    printl "  ${INFO} - Pulse Agent: Install the Agent.\n\n"
    $PLSAGTDLFLD/iotc-agent/install.sh 2>&1 | tee -a $LOGFILE
    if [ $? -eq 0 ]; then
        printl "  ${TICK} - Pulse Agent: Installed in /opt/vmware/iotc-agent"
    else 
        printl "  ${CROSS} - Pulse Agent: Installation NOT succesful."
    fi
}

## Auto - If installed, uninstall
doPulseAgentUninstall() {
    ## Uninstall the Pulse Agent
    printl "  ${ESCL} - Pulse Agent: Uninstall the agent.\n\n"
    /opt/vmware/iotc-agent/uninstall.sh 2>&1 | tee -a $LOGFILE
    if [ $? -eq 0 ]; then
        printl "  ${TICK} - Pulse Agent: Successfully uninstalled the agent."
        UNINSTALL_AGENT_SUCCES=true
    else
        printl "  ${CROSS} - Pulse Agent: Agent NOT uninstalled succesfully"
        UNINSTALL_AGENT_SUCCES=false
    fi
}

## Module Logic
modulePulseAgent() {
    printl "  ${INFO} Installation of the Pulse Agent..."

    ## Module variables
    PLSAGTINSTALLED="false"
    PLSAGTREINSTALL=0
    PLSAGTDLFLD=/tmp/pulseagent

    ## Module requirements
    if [ ! -d "$PLSAGTDLFLD" ]; then
        mkdir -p $PLSAGTDLFLD
        if [ $? -eq 0 ]; then
            printl "  ${TICK} - Pulse Agent download folder created succesful." 
        else
            printl "  ${CROSS} - Pulse Agent download folder creation NOT succesful."
        fi
    fi

    getPulseInstanceDetails
    testPulseInstanceConnectivity
    getPulseAgentLatestVersionInfo
    pulseAgentAlreadyInstalled
    if [[ $PLSAGTINSTALLED == "true" ]]; then
        doPulseAgentUninstall
        doPulseAgentDownload
        doPulseAgentInstall
    else
        # printl "Pulse Agent is not installed."
        # Let's go install the agent.
        doPulseAgentDownload
        doPulseAgentInstall
    fi

    ## Cleanup variables
    PLSAGTDLFLD=""
    PLSAGTVERSION=""
    PULSEINSTANCE=""
    PULSEADDENDUM=""
    PULSEHOST=""
    PULSEPORT=""
    TIMEOUT=""
    PULSEAGENTX86=""
    PULSEAGENTARM=""
    PULSEAGENTARM64=""
    PULSEURLX86=""
    PULSEURLARM=""
    PULSEURLARM64=""
    PLSAGTREINSTALL=""
    PLSAGTINSTALLED=""

    printl "  ${TICK} Pulse Agent Installation: Nothing more to do. Exiting this part.\n"

}

PULSEINSTANCE="iotc008"
modulePulseAgent

shutdown -r now

###############################
# Onboadring comes separately #
###############################
