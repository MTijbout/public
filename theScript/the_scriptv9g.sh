#!/bin/bash
################################################################################
# Filename: theScript.sh
# Date Created: 04/27/19
# Author: Marco Tijbout
#
# Version 0.9g
#
# Description: Script to show menu to select what modifications need to be
#              made to the OS.
#
# Usage: Run with SUDO. 
#        The script requires internet connectivity.
#
# Enhancement ideas:
#   -Making all the action in to functions so the order can easyly be adjusted.
#   -AlreadyRun: Log what actions are already run. Ask double check.
#
# Version history:
# 1.0  Marco Tijbout:
#   Publishing of script to public.
# 0.9g Marco Tijbout:
#   HOST_RENAME: Provided inputbox for manual input of new hostname.
# 0.9f Marco Tijbout:
#   Replacing ECHO with printl for logging purposes.
#   REGENERATE_SSH_KEYS: Updated how to regenerate keys so all OSses work.
#   AGENT_UNINSTALL: Uninstall Agent from Gateway.
# 0.9e Marco Tijbout:
#   Password input boxes for creating the system administrator account
#   Password unput box for enrolling a gateway to Pulse.
# 0.9d Marco Tijbout:
#   Added color scheme to menu.
#   Added THING_UNENROLL: Unenrolling a Thing Device.
#   Added GATEWAY_UNENROLL: Unenrolling a Gateway Device.
#   Added comments to the sub actions for readability.
#   Added CENTOS check and adoptions for package manager.
# 0.9c Marco Tijbout: 
#   SHOW_IP: Issues, but found an easier way. Just show all IPv4 addresses.
# 0.9b Marco Tijbout: 
#   PULSE_AGENT: Revamped Pulse Agent downloading.
#   CUSTOM_ALIAS: Aliases for ease of use of command line.
#   SHOW_IP: Build check for OS differences in NIC names.
# 0.8  Marco Tijbout:
#   Version for testing in the field.
# 0.7  Marco Tijbout:
#   Optimized Pulse related parts.
# 0.5  Marco Tijbout:
#   Added sub-menu functionality
# 0.1  Marco Tijbout:
#   Initial creation of the script.
################################################################################

################################################################################
#                            - INITIAL ROUTINES -                              #
################################################################################

## The user that executed the script.
USERID=$(logname)
# if [ "$EUID" == 0 ]; then 
#     WORKDIR=/$USERID
# else
WORKDIR=/home/$USERID
# fi

## Log file definition
LOGFILE=$0-`date +%Y-%m-%d_%Hh%Mm`.log

## Logging and ECHO functionality combined.
printl() {
    printf "\n%s" "$1"
    echo -e "$1" >> $LOGFILE
}

## BEGIN CHECK SCRIPT RUNNING UNDER SUDO 
if [ "$EUID" -ne 0 ]; then 
    printl ""
    printl "Please run this script using sudo."
    printl ""
    exit 1
fi

## Get Operating System information.
. /etc/os-release
OPSYS=${ID^^}
# printl "OPSYS: $OPSYS"

## If the OS is exotic, exit.
if [[ $OPSYS != *"RASPBIAN"* ]] && [[ $OPSYS != *"DEBIAN"* ]] && [[ $OPSYS != *"UBUNTU"* ]] && [[ $OPSYS != *"CENTOS"* ]] && [[ $OPSYS != *"DIETPI"* ]]; then
    printl "${BIRed}By the look of it, not one of the supported operating systems - aborting${BIWhite}\r\n"; exit
fi

## Check for OS that uses other update mechanisms.
if [[ $OPSYS == *"CENTOS"* ]]; then
    PCKMGR="yum"
    printl "For use with $OPSYS the package manager is set to $PCKMGR"
    AQUIET="--quiet"
    NQUIET="-s"
else
    PCKMGR="apt-get" 
    printl "For use with $OPSYS the package manager is set to $PCKMGR"
    AQUIET="-qq"
    NQUIET="-s"
fi

## Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
startTime="$(date +%s)"
columns=$(tput cols)
user_response=""
SECONDS=0
REBOOTREQUIRED=0

## Color settings
## High Intensity
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

## Bold High Intensity
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIPurple='\e[1;95m'     # Purple
BIMagenta='\e[1;95m'    # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

## Whiptail Color Settings
export NEWT_COLORS='
root=black,lightgray
title=yellow,blue
window=,blue
border=white,blue
textbox=white,blue
button=black,white
shadow=,gray
'

## Determine CPU Architecture:
CPUARCH=$(lscpu | grep Architecture | tr -d ":" | awk '{print $2}')
#printl "CPU Architecture: $CPUARCH"
#i686 - 32-bit OS

## Determine CPU Cores:
ACTIVECORES=$(grep -c processor /proc/cpuinfo)
#printl "CPU Cores: $ACTIVECORES"

## Determine current IP address:
MY_IP=$(hostname -I)

printstatus() {
    h=$(($SECONDS/3600));
    m=$((($SECONDS/60)%60));
    s=$(($SECONDS%60));
    printf "\r\n${BIGreen}==\r\n== ${BIYellow}$1"
    printf "\r\n${BIGreen}== ${IBlue}Total: %02dh:%02dm:%02ds Cores: $ACTIVECORES \r\n${BIGreen}==${IWhite}\r\n\r\n"  $h $m $s;
    printl ""
    printl "############################################################"
    printl "$1"
    printl ""
}

testInternetConnection() {
## Test internet connection.
    chmod u+s /bin/ping
    if [[ "$(ping -c 1 23.1.68.60  | grep '100%' )" != "" ]]; then
        printl "${IRed} No internet connection available, aborting! ${IWhite}\r\n"
        exit 0
    fi
}

################################################################################
## MAIN SECTION OF SCRIPT
################################################################################

printstatus "Welcome to THE SCRIPT!"

printstatus "Making sure THE SCRIPT works..."

## Test internet connection.
## Disable for offline testing purposes. E.g. in VMs and no internet connection.
#testInternetConnection

## Install required software for functional menu.
$PCKMGR $AQUIET -y install whiptail ccze net-tools curl 2>&1 | tee -a $LOGFILE

install_lsb_release() {
    ## install lsb_release if not present.
    if [[ $OPSYS == *"CENTOS"* ]]; then
        LSB_PACKAGE="redhat-lsb-core"
    else
        LSB_PACKAGE="lsb-release"
    fi
    [ ! -x /usr/bin/lsb_release ] && $PCKMGR $AQUIET -y update > /dev/null 2>&1 && $PCKMGR $AQUIET -y install $LSB_PACKAGE 2>&1 | tee -a $LOGFILE
}
install_lsb_release

DISTRO=$(/usr/bin/lsb_release -rs)
CHECK64=$(uname -m)
printl "DISTRO: $DISTRO"
printl "CHECK64: $CHECK64"
printl "OPSYS: $OPSYS"

#if [ ! -f /etc/AlreadyRun ]; then
#    printl "${BIRed}Script has already run - aborting${BIWhite}\r\n"; exit
#fi


## Create anchor to see if script already run.
touch /etc/AlreadyRun

################################################################################
## Main Menu Definition
################################################################################

main_menu1() {
    MMENU1=$(whiptail --title "Main Menu Selection" --checklist --notags \
        "\nSelect items as required then hit OK " 25 75 16 \
        "QUIET" "Quiet(er) install - untick for lots of info " OFF \
        "CUST_OPS" "Menu - Customization options " ON \
        "SEC_OPS" "Menu - Options for securing the system " OFF \
        "PULSE_OPS" "Menu - VMware Pulse Options " OFF \
        "log2ram" "Install Log2RAM with custom capacity " OFF \
        3>&1 1>&2 2>&3)
printl "Output MainMenu1: $MMENU1"
MYMENU="$MYMENU $MMENU1"
}

################################################################################
## Sub Menus Definition
################################################################################

sub_menu1() {
    SMENU1=$(whiptail --checklist --notags --title "Select customization options" \
        "\nSelect items as required then hit OK " 25 75 16 \
        "SHOW_IP" "Show IP on logon screen " OFF \
        "CUSTOM_PROMPT" "Updated Prompt " OFF \
        "CUSTOM_ALIAS" "Aliases for ease of use " OFF \
        "CHANGE_LANG" "Change Language to US-English " OFF \
        "NO_PASS_SUDO" "Remove sudo password requirement (NOT SECURE!) " OFF \
        3>&1 1>&2 2>&3)
printl "Output SubMenu1: $SMENU1"
MYMENU="$MYMENU $SMENU1"
}

sub_menu2() {
    SMENU2=$(whiptail --checklist --notags --title "Select securing options" \
        "\nSelect items as required then hit OK " 25 75 16 \
        "CREATE_SYSADMIN" "Create alternative sysadmin account " OFF \
        "UPDATE_HOST" "Apply latest updates available " OFF \
        "REGENERATE_SSH_KEYS" "Regenerate the SSH host keys " OFF \
        "HOST_RENAME" "Rename the HOST " OFF \
        3>&1 1>&2 2>&3)
printl "Output SubMenu2: $SMENU2"
MYMENU="$MYMENU $SMENU2"
}

sub_menu3() {
    SMENU3=$(whiptail --checklist --notags --title "Select Pulse options" \
        "\nSelect items as required then hit OK " 25 75 16 \
        "PULSE_AGENT" "Install VMware Pulse Center Agent " OFF \
        "ENROLL_GATEWAY" "Enroll Gateway to Pulse " OFF \
        "ENROLL_THING" "Enroll Thing onto Gateway " OFF \
        "AGENT_INTERVAL" "Change Pulse Agent update interval " OFF \
        "PACKAGE_CLI" "Download the Pulse package cli " OFF \
        "THING_UNENROLL" "Unenroll Thing from Gateway " OFF \
        "GATEWAY_UNENROLL" "Unenroll Gateway from Pulse " OFF \
        "AGENT_UNINSTALL" "Uninstall Agent from Gateway " OFF \
        3>&1 1>&2 2>&3)
printl "Output SubMenu3: $SMENU3"
MYMENU="$MYMENU $SMENU3"
}
        
################################################################################
## Calling the Menus
################################################################################

## Call main menu
main_menu1

## Call Submenus
if [[ $MYMENU == *"CUST_OPS"* ]]; then
    sub_menu1
fi

if [[ $MYMENU == *"SEC_OPS"* ]]; then
    sub_menu2
fi

if [[ $MYMENU == *"PULSE_OPS"* ]]; then
    sub_menu3
fi

if [[ $MYMENU != *"QUIET"* ]]; then
    AQUIET=""
    NQUIET=""
fi

if [[ $MYMENU == "" ]]; then
    whiptail --title "Installation Aborted" --msgbox "Cancelled as requested." 8 78
    exit
fi

################################################################################
##                  - Executing on the selected items -                       ##
################################################################################

################################################################################
# Force the system to use en_US as the language.
################################################################################
if [[ $MYMENU == *"CHANGE_LANG"* ]]; then
    printstatus "Change the systems language settings to en_US ..."

    printl "Check if language settings exists in system environments settings. If notadd them."
    if grep -Fxq "LANGUAGE = en_US" /etc/environment
    then
        printl "String found, /etc/environment does not need updating."
        break
    else
        printl "String not found, settings will be added to /etc/environment"

    ## Add language settings to the system environments settings.
    ## Added .utf-8 for error on CentOS
cat > /etc/environment << EOF
LANGUAGE = en_US.utf-8
LC_ALL = en_US.utf-8
LANG = en_US.utf-8
LC_TYPE = en_US.utf-8
EOF
    fi

    if [[ $OPSYS == *"CENTOS"* ]]; then
        localedef -i en_US -f UTF-8 en_US.UTF-8
    fi

    printl "Check the SSH server config not to accept settings from client."
    if grep -Fxq "#AcceptEnv LANG LC_*" /etc/ssh/sshd_config
    then
        printl "/etc/ssh/sshd_config already updated."
    elif grep -Fxq "AcceptEnv LANG LC_*" /etc/ssh/sshd_config
    then
        printl "/etc/ssh/sshd_config does need updating."

        ## Define the new value
        NEWVALUE="#AcceptEnv LANG LC_*"

        ## Replace the current line with the new one in the
        sed -i "/AcceptEnv/c$NEWVALUE" "/etc/ssh/sshd_config"
        printl "/etc/ssh/sshd_config is updated."

    else
        printl "Not found at all. Add."
        NEWVALUE="#AcceptEnv LANG LC_*"
        echo "$NEWVALUE" >> /etc/ssh/sshd_config
        printl "The value: $NEWVALUE is added to sshd_config"
    fi
    ## Restart the sshd service.
    systemctl restart sshd
    if [ $? -eq 0 ]; then
        printl "sshd service is restarted."
    else 
        printl "Could not restart sshd service."
    fi
    ## Have the script reboot at the end.
    REBOOTREQUIRED=1

    ## Cleanup variables
    NEWVALUE=""
fi

################################################################################
# Creating a system administrator account. 
################################################################################
if [[ $MYMENU == *"CREATE_SYSADMIN"* ]]; then
    printstatus "Creating alternative administrative account..."

    ADMINNAME=sysadmin
    ADMINNAME=$(whiptail --title "Administrative Account" --inputbox "\nEnter the name of the administrative account:\n" 8 60 $ADMINNAME 3>&1 1>&2 2>&3)

    if [ $USERID == $ADMINNAME ]; then
        whiptail --title "Administrative Account" --infobox "You are already using the $ADMINNAME account." 8 78
    else

    USERPASS=$(whiptail --passwordbox "Enter a user password" 8 60 3>&1 1>&2 2>&3)
    if [[ -z "${USERPASS// }" ]]; then
        printf "No user password given - aborting${BIWhite}\r\n"; exit
    fi

    USERPASS2=$(whiptail --passwordbox "Confirm user password" 8 60 3>&1 1>&2 2>&3)
    if  [ $USERPASS2 == "" ]; then
        printf "${BIRed}No password confirmation given - aborting${BIWhite}\r\n"; exit
    fi

    if  [ $USERPASS != $USERPASS2 ]
    then
        printf "${BIRed}Passwords don't match - aborting${BIWhite}\r\n"; exit
    fi

    SRC=$USERID
    DEST=$ADMINNAME

    SRC_GROUPS=$(groups ${SRC})
    SRC_SHELL=$(awk -F : -v name=${SRC} '(name == $1) { print $7 }' /etc/passwd)
    NEW_GROUPS=""
    i=0

    #skip first 3 entries this will be "username", ":", "defaultgroup"
    for gr in $SRC_GROUPS
    do
        if [ $i -gt 2 ]
        then
            if [ -z "$NEW_GROUPS" ]; then NEW_GROUPS=$gr; else NEW_GROUPS="$NEW_GROUPS,$gr"; fi
        fi
        (( i++ ))
    done

    printl "New user will be added to the following groups: $NEW_GROUPS"

    useradd --groups ${NEW_GROUPS} --shell ${SRC_SHELL} --create-home ${DEST}
    mkhomedir_helper ${DEST}
    #passwd ${DEST}

    ## Add the specified password to the account.
    echo $ADMINNAME:$USERPASS | chpasswd

    printstatus "The account $ADMINNAME is created..."

    ## Cleanup variables
    USERPASS=""
    USERPASS2=""
    ADMINNAME=""
    SRC=""
    DEST=""
    SRC_GROUPS=""
    SRC_SHELL=""
    NEW_GROUPS=""
    gr=""
    fi
fi

################################################################################
# Updating the Host.
################################################################################
if [[ $MYMENU == *"UPDATE_HOST"* ]]; then
    ## Perform all the updates available.
    printstatus "Update the Host with the latest available updates..."
    
    if [[ $ == *"CENTOS"* ]]; then
        $PCKMGR $AQUIET check-update 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET update 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET -y autoremove 2>&1 | tee -a $LOGFILE
        #$PCKMGR $AQUIET -y clean 2>&1 | tee -a $LOGFILE
    else
        $PCKMGR $AQUIET update 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET -y upgrade 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET -y dist-upgrade 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET -y autoremove 2>&1 | tee -a $LOGFILE
        $PCKMGR $AQUIET -y autoclean 2>&1 | tee -a $LOGFILE
    fi
    ## Have the script reboot at the end.
    REBOOTREQUIRED=1
fi

################################################################################
# Regenerate the Host SSH keys.
################################################################################
if [[ $MYMENU == *"REGENERATE_SSH_KEYS"* ]]; then
    printstatus "Regenerate SSH Host keys..."

    ## Get the current public SSH key of the host.
    SSHFINGERPRINT=$(ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub | tr -d ":" | awk '{print $2}')
    ## log the value to syslog
    logger Old SSH fingerprint is: $SSHFINGERPRINT ## Add to syslog
    printl Old SSH fingerprint is: $SSHFINGERPRINT


    /bin/rm -v /etc/ssh/ssh_host_* 2>&1 | tee -a $LOGFILE
    ssh-keygen -t dsa -N "" -f /etc/ssh/ssh_host_dsa_key
    ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
    #dpkg-reconfigure openssh-server 2>&1 | tee -a $LOGFILE

    systemctl restart sshd 2>&1 | tee -a $LOGFILE

    ## Get the new public SSH key of the host.
    SSHFINGERPRINT=$(ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub | tr -d ":" | awk '{print $2}')
    logger New SSH fingerprint is: $SSHFINGERPRINT ## Add to syslog
    printl New SSH fingerprint is: $SSHFINGERPRINT

    ## Have the script reboot at the end.
    REBOOTREQUIRED=1
fi

################################################################################
# Show the IP address of the Host at the login screen.
################################################################################
if [[ $MYMENU == *"SHOW_IP"* ]]; then
    printstatus "Show the IP address at the logon screen..."

    TARGETFILE=/etc/issue
    if grep -Fq "IP Address" $TARGETFILE
    then
        printl "String found, $TARGETFILE does not need updating."
    else
        printl "String not found, settings will be added to $TARGETFILE"
        ## Backup issue file.
        cat /etc/issue >> /etc/issue.bak 2>&1 | tee -a $LOGFILE

        ## Get content and add info to issue file.
        cat $TARGETFILE > worker_file 2>&1 | tee -a $LOGFILE
        echo 'IP Address: \4' >> worker_file 2>&1 | tee -a $LOGFILE
        echo "" >> worker_file 2>&1 | tee -a $LOGFILE

        ## Replace the contend of the issue file.
        cat worker_file > $TARGETFILE 2>&1 | tee -a $LOGFILE

        ## Remove the worker file.
        rm worker_file 2>&1 | tee -a $LOGFILE

        ## Cleanup variables
        TARGETFILE=""
    fi
fi

################################################################################
# Rename the Host.
################################################################################
if [[ $MYMENU == *"HOST_RENAME"* ]]; then
    printstatus "Rename the Host..."

    ## Format the date and time strings 
    current_time=$(date "+%Y%m%d-%H%M%S")
    RDM="$(date +"%3N")"

    ## Get the last 4 characters of the MAC Address
    MAC=$(ifconfig | grep ether | tr -d ":" | awk '{print $2}' | tail -c 5)
    #printl "MAC: $MAC"

    ## The current and to be old name:
    OLDHOSTNAME="$(uname -n)"
    GENHOSTNAME=$OPSYS$RDM${MAC^^}

    NEWHOSTNAME=$(whiptail --title "Rename Host" --inputbox "\nEnter the new name for the Host:\n" 8 60 $GENHOSTNAME 3>&1 1>&2 2>&3)
    
    printl "The old hostname: $OLDHOSTNAME"
    printl "The generated hostname: $GENHOSTNAME"
    printl "The chosen hostname: $NEWHOSTNAME"

    ## Set the new hostname.
    hostnamectl set-hostname $NEWHOSTNAME

    ## Update the /etc/hosts file.
    if grep -Fq "127.0.1.1" /etc/hosts
    then
        ## If found, replace the line
        sed -i "/127.0.1.1/c\127.0.1.1    $NEWHOSTNAME" /etc/hosts
    else
        ## If not found, add the line
        echo '127.0.1.1    '$NEWHOSTNAME &>> /etc/hosts
    fi

    ## Check if Ubuntu Cloud config is used
    cloudFile="/etc/cloud/cloud.cfg"
    if [ -f "$cloudFile" ]
    then
        sed -i "/preserve_hostname/c\preserve_hostname: true" $cloudFile
    fi
    
    ## Have the script reboot at the end.
    REBOOTREQUIRED=1

    ## Cleanup variables
    RDM=""
    MAC=""
    OLDHOSTNAME=""
    GENHOSTNAME=""
    NEWHOSTNAME=""
    cloudFile=""
fi

################################################################################
# Apply a more convenient Prompt for the user.
################################################################################
if [[ $MYMENU == *"CUSTOM_PROMPT"* ]]; then
    printstatus "Change the prompt to a more user friendly one..."

    TARGETFILE="$WORKDIR/.bashrc"
    NEWPROMPT="export PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[00;33m\]\n   \u \[\033[01;34m\] at \[\033[00;33m\] \h\[\033[00m\] \[\033[01;34m\]in \[\033[00;33m\]\w\[\033[00m\]\n\\$ '"

    if grep -Fxq "## Custom prompt settings added ..." $TARGETFILE
    then
        printl "String found, $TARGETFILE does not need updating."
        break
    else
        printl "String not found, settings will be added to $TARGETFILE"
        echo "" >> $TARGETFILE
        echo "## Custom prompt settings added ..." >> $TARGETFILE
        echo "$NEWPROMPT" >> $TARGETFILE
    fi
    ## Cleanup variables
    TARGETFILE=""
    NEWPROMPT=""
fi

################################################################################
# Add additional aliases to the profile of the user.
################################################################################
if [[ $MYMENU == *"CUSTOM_ALIAS"* ]]; then
    printstatus "Add some aliases for ease of use..."

    TARGETFILE="$WORKDIR/.bash_aliases"
    WORKFILE2="$WORKDIR/.bashrc"
    ## Check if .bash_aliases will be loaded.
    if grep -Fq "bash_aliases" $WORKFILE2
    then
        ## If found, replace the line
        printl ".bashrc calls .bash_aliases. All good here."
    else
        ## If not found, add the line
        printl ".bashrc does not call .bash_aliases. Making sure it does."
cat >> $WORKFILE2 <<EOF
## Call the .bash_aliases file during logon.
if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi
EOF
        source $WORKFILE2
    fi

    if grep -Fxq "## Custom aliases added ..." $TARGETFILE
    then
        printl "String found, $TARGETFILE does not need updating."
        break
    else
        printl "String not found, settings will be added to $TARGETFILE"
        echo "" >> $TARGETFILE
        echo "## Custom aliases added ..." >> $TARGETFILE
        echo "$NEWPROMPT" >> $TARGETFILE
cat > $TARGETFILE << EOF
## Enable color
export CLICOLOR=true

## Own creations:
alias la='ls -la'   # list all
alias ll='ls -lhF'  # list all
alias dir='lla'     # List all in columns
alias lh='ll -h'    # list all
alias lx='ls -X'    # sort by extension
alias lt='ls -tr'   # sort by mod time, reverse order
alias lS='ls -S'    # sort by size
alias lL='ll -S'    # sort by size
alias lr='ls -R'    # recursive
alias ..='cd ..'    # up
alias watch='watch -d -n 1' # update every 1 second, showing changes
alias cls='clear'
alias br='source ~/.bash_profile'
EOF
    fi

    ## Cleanup variables
    TARGETFILE=""
    WORKFILE2=""
fi

################################################################################
# Remove the need to type a password when using sudo.
################################################################################
if [[ $MYMENU == *"NO_PASS_SUDO"* ]]; then
    printstatus "Remove for need of password performing sudo..."

    if ls /etc/sudoers.d/*$USERID*; then
        printl "Using password for sudo is not required for this user."
    else 
        printl "Removed for need of password performing sudo for this user."
        echo "$USERID ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/010_$USERID-nopasswd
        chmod 0440 /etc/sudoers.d/010_$USERID-nopasswd          
    fi
fi

################################################################################
# Install the VMware Pulse Agent.
################################################################################
if [[ $MYMENU == *"PULSE_AGENT"* ]]; then
    printstatus "Installation of the Pulse Agent..."

    PLSAGTDLFLD=/home/pulseagent
    #PLSAGTVERSION=2.0.0.548
    PLSAGTVERSION=2.0.0.589 # Sprint 05 build.

    ## TEST CONNECTION TO YOUR PULSE INSTANCE"
    PULSEINSTANCE=$(whiptail --inputbox "\nEnter your Pulse Console Instance (for example iotc001,iotc002, etc.):\n" --title "Installation Pulse Agent" 8 60 $PULSEINSTANCE 3>&1 1>&2 2>&3)
    PULSEADDENDUM="-pulse.vmware.com"
    printl "Pulse instance: $PULSEINSTANCE"
    PULSEHOST="$PULSEINSTANCE$PULSEADDENDUM"
    printl "Pulse host: $PULSEHOST"
    PULSEPORT=443
    TIMEOUT=1

    if [[ $OPSYS == *"CENTOS"* ]]; then
        ## Install nc if not present.
        [ ! -x /bin/nc ] && $PCKMGR $AQUIET -y update > /dev/null 2>&1 && $PCKMGR $AQUIET -y install nc 2>&1 | tee -a $LOGFILE
    fi

    if nc -w $TIMEOUT -z $PULSEHOST $PULSEPORT; then
        printl "CONNECTION SUCCESSFUL!"
        printl "Connection to the Pulse Server ${PULSEHOST} was Successful"
    else
        printl "CONNECTION FAILED!"
        printl "Connection to the Pulse Server ${PULSEHOST} Failed"
        printl "Please Confirm if the Pulse URL is correct"
        printl "If the Pulse URL is correct, then please ensure that we can open an outbound HTTPS connection to the Pulse Server over port 443"
        exit 1
    fi

    ## Prep download
    mkdir $PLSAGTDLFLD
    PULSEAGENTX86="iotc-agent-x86_64-$PLSAGTVERSION.tar.gz"
    PULSEAGENTARM="iotc-agent-arm-$PLSAGTVERSION.tar.gz"
    PULSEAGENTARM64="iotc-agent-aarch64-$PLSAGTVERSION.tar.gz"
    PULSEURLX86="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTX86"
    PULSEURLARM="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTARM"
    PULSEURLARM64="https://$PULSEHOST/api/iotc-agent/$PULSEAGENTARM64"

    checkPulseAgentDownload() {
        printl "Future: Check if Pulse Agent is already downloaded"
        ## Check if the agent is already downloaded. CHECKSUM?
        #@@@ Make sure we do not download unnecessary.
    }

    downloadPulseAgent() {
        ## Downloading the agent.
        curl -o $1/$2 $3 2>&1 | tee -a $LOGFILE
        printl "Pulse Agent for $4 is downloaded"
        ## Unpacking the agent.
        tar -xzf $1/$2 -C $1
        printl "Pulse Agent for $4 is unpacked."   
    }

    if [[ $CPUARCH == *"x86_64"* ]];then
        downloadPulseAgent "$PLSAGTDLFLD" "$PULSEAGENTX86" "$PULSEURLX86" "$CPUARCH"  
        elif [[ $CPUARCH == *"armv7l"* ]];then
            downloadPulseAgent "$PLSAGTDLFLD" "$PULSEAGENTARM" "$PULSEURLARM" "$CPUARCH"      
        elif [[ $CPUARCH == *"ARMv8"* ]];then
            downloadPulseAgent "$PLSAGTDLFLD" "$PULSEAGENTARM64" "$PULSEURLARM64" "$CPUARCH" 
        elif [[ $CPUARCH == *"i686"* ]];then
            printl "${BIRed}By the look of it, $CPUARCH is not one of the supported CPU Architectures - aborting${BIWhite}\r\n"; exit
        else
            printl "${BIRed}By the look of it, $CPUARCH is not one of the supported CPU Architectures - aborting${BIWhite}\r\n"; exit
    fi

    ## Set permissions
    chmod 777 $PLSAGTDLFLD/iotc-agent/install.sh
    chmod 777 $PLSAGTDLFLD/iotc-agent/uninstall.sh

    ## Installing the agent
    $PLSAGTDLFLD/iotc-agent/install.sh 2>&1 | tee -a $LOGFILE
    if [ $? -eq 0 ]; then
        printl "Installed the Pulse Agent in /opt/vmware/iotc-agent"
    else 
        printl "Pulse agent is not installed sucessfully."
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
fi

################################################################################
# Configure the Pull interal of the Pulse Agent.
################################################################################
if [[ $MYMENU == *"AGENT_INTERVAL"* ]]; then
    printstatus "Changing Pulse Agent update interval..."
    AGTINTERVAL=300
    AGTINTERVAL=$(whiptail --inputbox "\nProvide new update interval (in sec.) (default=300)):\n" --title "Pulse Agent" 8 60 $AGTINTERVAL 3>&1 1>&2 2>&3)
    NEWAGTINTERVAL="commandFetchIntervalSeconds = $AGTINTERVAL"

    #Replace the current line with the new one in the pulse config file.
    sed -i "/commandFetchIntervalSeconds/c$NEWAGTINTERVAL" "/opt/vmware/iotc-agent/conf/iotc-agent.cfg"
    if [ $? -eq 0 ]; then
        printl "The new value for pulling of the Pulse Agent is: $AGTINTERVAL seconds."
    else 
        printl "Value is not modified."
    fi

    #Restart the iotc-agent service.
    systemctl restart iotc-agent
    if [ $? -eq 0 ]; then
        printl "The service iotc-agent is succesfully restarted."
    else 
        printl "The service iotc-agent did not succesfully restart."
    fi
    ## Cleanup variables
    AGTINTERVAL=""
    NEWAGTINTERVAL=""
fi

################################################################################
# Enroll a Gateway Device into Pulse.
################################################################################
if [[ $MYMENU == *"ENROLL_GATEWAY"* ]]; then
    printstatus "Enrolling the Gateway to Pulse..."

    if [ ! -f /opt/vmware/iotc-agent/bin/DefaultClient ]; then 
        printf "${BIRed}Pulse agent is not installed - aborting${BIWhite}\r\n"; exit
    fi
    OLDNAME="$(uname -n)"
    TMPLNAME=G-UbuntuVM-MT-01
    GWNAME=CentOSVM-MT-LC01
    TMPPWFILE=/tmp/mypassword
    TMPLNAME=$(whiptail --inputbox "\nEnter the name of the Template to be used for your Gateway):\n" --title "Installation Pulse Agent" 8 60 $TMPLNAME 3>&1 1>&2 2>&3)
    GWNAME=$(whiptail --inputbox "\nEnter the name for your Gateway):\n" --title "Installation Pulse Agent" 8 60 $OLDNAME 3>&1 1>&2 2>&3)
    GWADMIN=$(whiptail --inputbox "\nEnter the username to enroll your Gateway):\n" --title "Installation Pulse Agent" 8 60 $GWADMIN 3>&1 1>&2 2>&3)

    USERPASS=$(whiptail --passwordbox "Enter a user password" 8 60 3>&1 1>&2 2>&3)
    if [[ -z "${USERPASS// }" ]]; then
        printf "No user password given - aborting${BIWhite}\r\n"; exit
    fi

    echo -n "$USERPASS" >$TMPPWFILE
    /opt/vmware/iotc-agent/bin/DefaultClient enroll --auth-type=BASIC --template=$TMPLNAME --name=$GWNAME --username=$GWADMIN --password=file:$TMPPWFILE
    if [ $? -eq 0 ]; then
        GWDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $1}' | awk -F '@' '{print $1}')
        printl "Gateway ID is: $GWDEVICEID"
    else 
        printl "Gateway is NOT enrolled sucessfully."
    fi

    ## Remove the temporary password file.
    rm -f $TMPPWFILE

    ## Cleanup variables
    OLDNAME=""
    TMPLNAME=""
    GWNAME=""
    GWADMIN=""
    USERPASS=""
    TMPPWFILE=""
fi

################################################################################
# Enroll a Thing Device onto the Gateway Device.
################################################################################
if [[ $MYMENU == *"ENROLL_THING"* ]]; then
    printstatus "Enrolling a THING onto the Gateway..."

    ## Check if agent is installed.
    if [ ! -f /opt/vmware/iotc-agent/bin/DefaultClient ]; then 
        printf "${BIRed}Pulse agent is not installed - aborting${BIWhite}\r\n"; exit
    fi

    ## Check if Gateway is enrolled.
    GWDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $1}' | awk -F '@' '{print $1}')
    if [[ $GWDEVICEID == "" ]]; then
        printf "${BIRed}Gateway is not enrolled yet - aborting${BIWhite}\r\n"; exit
    fi

    ## Gather details for enrolling Thing to Gateway.
    TTMPLNAME=$(whiptail --inputbox "\nEnter the name of the Template to be used for your Thing Device):\n" --title "Enroll a THING to Gateway" 8 60 $TTMPLNAME 3>&1 1>&2 2>&3)
    TNGNAME=$(whiptail --inputbox "\nEnter the name for your Thing Device):\n" --title "Enroll THING to Gateway" 8 60 3>&1 1>&2 2>&3)

    ## Enroll the Thing.
    /opt/vmware/iotc-agent/bin/DefaultClient enroll --template=$TTMPLNAME --name=$TNGNAME --parent-id=$GWDEVICEID

    ## Check and log success.
    if [ $? -eq 0 ]; then
        TNGDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $2}' | awk -F '@' '{print $2}')
        printl "Thing device is enrolled sucessfully."
        printl "Thing ID is: $TNGDEVICEID"
    else 
        printl "Thing device is NOT enrolled sucessfully."
    fi
    
    ## Cleanup variables
    GWDEVICEID=""
    TTMPLNAME=""
    TNGNAME=""
    TNGDEVICEID=""
fi

################################################################################
# Unenroll a Thing Device from the Gateway Device.
################################################################################
if [[ $MYMENU == *"THING_UNENROLL"* ]]; then
    printstatus "Unenrolling a THING from the Gateway..."

    ## Check if agent is installed.
    if [ ! -f /opt/vmware/iotc-agent/bin/DefaultClient ]; then 
        printf "${BIRed}Pulse agent is not installed - aborting${BIWhite}\r\n"; exit
    fi

    ## Check if Thing Device is enrolled.
    TNGDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $2}' | awk -F '@' '{print $2}')
    if [[ $GWDEVICEID == "" ]]; then
        printf "${BIRed}Gateway is not enrolled yet - aborting${BIWhite}\r\n"; exit
    fi

    ## Unenroll the Thing Device.
    /opt/vmware/iotc-agent/bin/DefaultClient unenroll --device-id=$TNGDEVICEID
    
    ## Check and log success.
    if [ $? -eq 0 ]; then
        printl "Thing device unenrolled sucessfully."
    else 
        printl "Thing device is NOT unenrolled sucessfully."
    fi
    
    ## Cleanup variables
    TNGDEVICEID=""
fi

################################################################################
# Unenroll a Gateway Device from Pulse.
################################################################################
if [[ $MYMENU == *"GATEWAY_UNENROLL"* ]]; then
    printstatus "Unenrolling a GATEWAY from Pulse..."

    ## Check if agent is installed.
    if [ ! -f /opt/vmware/iotc-agent/bin/DefaultClient ]; then 
        printf "${BIRed}Pulse agent is not installed - aborting${BIWhite}\r\n"; exit
    fi

    ## Check if Thing Device is enrolled.
    GWDEVICEID=$(cat -v /opt/vmware/iotc-agent/data/data/deviceIds.data | awk -F '^' '{print $1}' | awk -F '@' '{print $1}')
    if [[ $GWDEVICEID == "" ]]; then
        printf "${BIRed}Gateway is not enrolled - aborting${BIWhite}\r\n"; exit
    fi

    ## Unenroll the Thing Device.
    /opt/vmware/iotc-agent/bin/DefaultClient unenroll --device-id=$GWDEVICEID
    
    ## Check and log success.
    if [ $? -eq 0 ]; then
        printl "Gateway device unenrolled sucessfully."
    else 
        printl "Gateway device is NOT unenrolled sucessfully."
    fi

    ## Cleanup variables
    GWDEVICEID=""
fi

################################################################################
# Uninstall the agent from the Gateway Device.
################################################################################
if [[ $MYMENU == *"AGENT_UNINSTALL"* ]]; then
    printstatus "Uninstalling the Pulse Agent from the gateway..."
    /opt/vmware/iotc-agent/uninstall.sh
    if [ $? -eq 0 ]; then
        printl "Pulse Agent uninstalled sucessfully."
    else 
        printl "Pulse Agent is NOT uninstalled sucessfully."
    fi
fi

################################################################################
# Download the Pulse package-cli onto the host.
################################################################################
if [[ $MYMENU == *"PACKAGE_CLI"* ]]; then
    if [[ $CPUARCH == *"armv7l"* ]];then
        whiptail --title "Sorry, not available" --msgbox "Sorry, there is no package-cli for the $CPUARCH architecture available. You must hit OK to continue." 8 78
        printstatus "Sorry, there is no package-cli for the $CPUARCH architecture available"
        break
    fi

    printstatus "Download the package-cli to the Gateway..."
    ## Make sure unzip is installed.
    $PCKMGR $AQUIET -y install unzip

    ## Gather all information for downloading file.
    PULSEINSTANCE=$(whiptail --inputbox "\nEnter your Pulse Console Instance (for example iotc001,iotc002, etc.):\n" --title "Installation Package-CLI" 8 60 $PULSEINSTANCE 3>&1 1>&2 2>&3)
    PULSEADDENDUM="-pulse.vmware.com"
    PULSEHOST="$PULSEINSTANCE$PULSEADDENDUM"
    CLIPACKAGE="/api/iotc-cli/package-cli.zip"
    PULSECLIURL="https://$PULSEHOST$CLIPACKAGE"

    ## Downloading the package-cli bundle.
    curl -o $WORKDIR/package-cli.zip $PULSECLIURL 2>&1 | tee -a $LOGFILE

    ## Unzip only OS-bit specific package-cli
    if [[ $CPUARCH == *"x86_64"* ]];then
        unzip -j ~/package-cli.zip linux_amd64/package-cli -d /usr/bin
        printl "package-cli for the $CPUARCH architecture is put in the $WORKDIR/bin folder"
    elif [[ $CPUARCH == *"i686"* ]];then
        unzip -j ~/package-cli.zip darwin_386/package-cli -d /usr/bin
        printl "package-cli for the $CPUARCH architecture is put in the $WORKDIR/bin folder"
    else
        printl "By the look of it, not one of the supported CPU Architectures."
    break
    fi

    ## Make package-cli systemwide accessible.
    ln -s $WORKDIR/bin/package-cli /usr/bin/package-cli

    ## Cleanup variables
    PULSEINSTANCE=""
    PULSEADDENDUM=""
    PULSEHOST=""
    CLIPACKAGE=""
    PULSECLIURL=""
fi

################################################################################
# Install Log2RAM to extend the life SD cards.
################################################################################
if [[ $MYMENU == *"log2ram"* ]]; then
    if [[ $ != *"RASPBIAN"* ]]; then
        if [ ! -f /etc/log2ram.conf ]; then
            printstatus "Installing Log2RAM"
            $PCKMGR $AQUIET -y install git 2>&1 | tee -a $LOGFILE
            cd $WORKDIR
            git clone https://github.com/azlux/log2ram.git 2>&1 | tee -a $LOGFILE
            cd log2ram
            chmod +x install.sh
            ./install.sh 2>&1 | tee -a $LOGFILE
            cd $WORKDIR
        else
            printstatus "Log2Ram is already installed."
        fi

        ## Increase Log2RAM capacity
        printstatus "Increase Log2RAM capacity."

        L2RDEFVAL=40M
        L2RDEFVAL=$(whiptail --inputbox "\nProvide new capacity (for example 192M)):\n" --title "Log2RAM Capacity" 8 60 $L2RDEFVAL 3>&1 1>&2 2>&3)

        if grep -Fq "SIZE" /etc/log2ram.conf; then
            # Replace the line with the new value.
            sed -i "/SIZE/c\SIZE=$L2RDEFVAL" /etc/log2ram.conf
            printl "New capacity value for Log2RAM is: $L2RDEFVAL"

            ## Have the script reboot at the end.
            REBOOTREQUIRED=1
        fi
    else
        whiptail --title "Alert!" --msgbox "Log2RAM can only be installed on RASPBIAN." 8 78
        printl "Log2RAM can only be installed on RASPBIAN"
    fi

    ## Cleanup variables
    L2RDEFVAL=""
fi

################################################################################
## Some cleanup at the end...
################################################################################
#rm -rf /var/cache/apt/archives/apt-fast
#$PCKMGR $AQUIET -y clean 2>&1 | tee -a $LOGFILE

printstatus "All done."
printf "${BIGreen}== ${BIYELLOW}When complete, remove the script from the /home/$USERID directory.\r\n"
printf "${BIGreen}==\r\n"
printf "${BIGreen}== ${BIPurple}Current IP: %s${BIWhite}\r\n" "$MY_IP"
printl "Current IP: $MY_IP"
printl "Changed Hostname: $NEWHOSTNAME"

if [[ $REBOOTREQUIRED == *"1"* ]]; then
    if (whiptail --title "Script Finished" --yesno "Changes made require a REBOOT.\nOK?" 8 78); then
        printl "Script is Finished. Rebooting now."
        shutdown -r now 
    else
        whiptail --title "Script Finished" --msgbox "Changes made require a REBOOT.\nPlease reboot ASAP." 8 78
        printl "Script is Finished. Changes made require a reboot. Pleae REBOOT asap!"
    fi
else
    printl "ALL DONE - No reboot required. But will not harm by doing."
fi
