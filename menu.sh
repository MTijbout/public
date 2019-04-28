#!/bin/bash
#!/bin/bash
#############################################################################
# Filename: theScript.sh
# Date Created: 04/27/19
# Author: Marco Tijbout
#
# Version 1.0
#
# Description: Script to show menu to select what modifications need to be
#              made to the OS.
#
# Usage: Run as SUDO or ROOT
#
# Version history:
# 1.0 - Marco Tijbout: Original working script.
#############################################################################

##
## INITIAL ROUTINES
## 

## BEGIN CHECK SCRIPT RUNNING AS ROOT 
if [ "$EUID" -ne 0 ]
  then echo "Please run this script as Root"
  exit
fi

## Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
startTime="$(date +%s)"
columns=$(tput cols)
user_response=""
SECONDS=0

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

skip=0
other=0

clean_stdin()
{
    while read -r -t 0; do
        read -n 256 -r -s
    done
}

stopit=0
other=0
yes=0
nohelp=0
hideother=0

timecount(){
    sec=30
    while [ $sec -ge 0 ]; do
        if [ $nohelp -eq 1 ]; then
            
            if [ $hideother -eq 1 ]; then
                printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}n${BIPurple}(o)/${BIWhite}a${BIPurple}(ll)/${BIWhite}e${BIPurple}(nd)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
            else
                printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}o${BIPurple}(ther)/${BIWhite}e${BIPurple}(nd)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
            fi
        else
            printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}h${BIPurple}(elp)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
        fi
        sec=$((sec-1))
        trap '' 2
        stty -echo
        read -t 1 -n 1 user_response
        stty echo
        trap - 2
        if [ -n  "$user_response" ]; then
            break
        fi
    done
}

ACTIVECORES=$(grep -c processor /proc/cpuinfo)

LOGFILE=$HOME/$0-`date +%Y-%m-%d_%Hh%Mm`.log

printl() {
	printf $1
	echo -e $1 >> $LOGFILE
}

printstatus() {
    h=$(($SECONDS/3600));
    m=$((($SECONDS/60)%60));
    s=$(($SECONDS%60));
    printf "\r\n${BIGreen}==\r\n== ${BIYellow}$1"
    printf "\r\n${BIGreen}== ${IBlue}Total: %02dh:%02dm:%02ds Cores: $ACTIVECORES \r\n${BIGreen}==${IWhite}\r\n\r\n"  $h $m $s;
	echo -e "############################################################" >> $LOGFILE
	echo -e $1 >> $LOGFILE
}

############################################################################
##
## MAIN SECTION OF SCRIPT - action begins here
##
#############################################################################

printstatus "Welcome to THE SCRIPT!"
printstatus "Grabbing some preliminaries..."

AQUIET="-qq"
NQUIET="-s"

## Install Whiptail menu.
 apt-get $AQUIET -y install whiptail ccze net-tools 2>&1 | tee -a $LOGFILE

## Get Operating System information.
. /etc/os-release
OPSYS=${ID^^}
echo -e OPSYS: $OPSYS >> $LOGFILE

# test internet connection
 chmod u+s /bin/ping
if [[ "$(ping -c 1 23.1.68.60  | grep '100%' )" != "" ]]; then
    printl "${IRed}!!!! No internet connection available, aborting! ${IWhite}\r\n"
    exit 0
fi

## install lsb_release if not present.
[ ! -x /usr/bin/lsb_release ] && apt-get $AQUIET -y update > /dev/null 2>&1 && apt-get $AQUIET -y install lsb-release 2>&1 | tee -a $LOGFILE
DISTRO=$(/usr/bin/lsb_release -rs)
CHECK64=$(uname -m)
echo -e DISTRO: $DISTRO >> $LOGFILE
echo -e CHECK64: $CHECK64 >> $LOGFILE

#if [[ $OPSYS == *"UBUNTU"* ]]; then
#    if [ $DISTRO != "16.04" ] ; then
#        printl "${IRed}!!!! Wrong version of Ubuntu - not 16.04, aborting! ${IWhite}\r\n"
#        exit 0
#    fi
#fi

#if [ ! -f /etc/AlreadyRun ]; then
#    printl "${BIRed}Script has already run - aborting${BIWhite}\r\n"; exit
#fi

## If very exotic, exit.
if [[ $OPSYS != *"RASPBIAN"* ]] && [[ $OPSYS != *"DEBIAN"* ]] && [[ $OPSYS != *"UBUNTU"* ]] && [[ $OPSYS != *"DIETPI"* ]]; then
    printl "${BIRed}By the look of it, not one of the supported operating systems - aborting${BIWhite}\r\n"; exit
fi

## Create anchor to see if script already run.
touch /etc/AlreadyRun


##
## Start the Menu
##
if [[ $OPSYS == *"RASPBIAN"* ]];then
    MYMENU=$(whiptail --title "Main Raspberry Pi Selection" --checklist \
        "\nSelect items for your Pi as required then hit OK " 28 73 21 \
        "quiet" "Quiet(er) install - untick for lots of info " OFF \
        "prereq" "Install general pre-requisites " OFF \
        "securing" "For the more security minded " OFF \
        "showiplogon" "Show IP on logon screen " ON \
        "hostRename" "Rename the HOST " ON \
        "installPulseAgent" "Install VMware Pulse Center Agent " OFF \
        "menu_option_05" "Description of menu option... " OFF \
        "menu_option_06" "Description of menu option... " OFF \
        "log2ram" "Install Log2RAM default 40 Meg" OFF 3>&1 1>&2 2>&3)
else
    MYMENU=$(whiptail --title "Main Non-Pi Selection" --checklist \
        "\nSelect items as required then hit OK " 30 73 23 \
        "quiet" "Quiet(er) install - untick for lots of info " OFF \
        "prereq" "Install general pre-requisites " OFF \
        "securing" "For the more security minded " OFF \
        "showiplogon" "Show IP on logon screen " ON \
        "hostRename" "Rename the HOST " ON \
        "installPulseAgent" "Install VMware Pulse Center Agent " OFF \
        "menu_option_05" "Description of menu option... " OFF \
        "menu_option_06" "Description of menu option... " OFF \
        "log2ram" "Install Log2RAM default 40 Meg" OFF 3>&1 1>&2 2>&3)
fi

if [[ $MYMENU != *"quiet"* ]]; then
    AQUIET=""
    NQUIET=""
fi

if [[ $MYMENU == "" ]]; then
    whiptail --title "Installation Aborted" --msgbox "Cancelled as requested." 8 78
    exit
fi

if [[ $MYMENU == *"modpass"* ]]; then
    
    username=$(whiptail --inputbox "Enter a USER name (example user)\nSpecifically for Node-Red Dashboard" 8 60 $username 3>&1 1>&2 2>&3)
    if [[ -z "${username// }" ]]; then
        printf "No user name given - aborting\r\n"; exit
    fi
    
    userpass=$(whiptail --passwordbox "Enter a user password" 8 60 3>&1 1>&2 2>&3)
    if [[ -z "${userpass// }" ]]; then
        printf "No user password given - aborting${BIWhite}\r\n"; exit
    fi
    
    userpass2=$(whiptail --passwordbox "Confirm user password" 8 60 3>&1 1>&2 2>&3)
    if  [ $userpass2 == "" ]; then
        printf "${BIRed}No password confirmation given - aborting${BIWhite}\r\n"; exit
    fi
    if  [ $userpass != $userpass2 ]
    then
        printf "${BIRed}Passwords don't match - aborting${BIWhite}\r\n"; exit
    fi
    
    adminname=$(whiptail --inputbox "Enter an ADMIN name (example admin)\nFor Node-Red and MQTT" 8 60 $adminname 3>&1 1>&2 2>&3)
    if [[ -z "${adminname// }" ]]; then
        printf "${BIRed}No admin name given - aborting${BIWhite}\r\n"
        exit
    fi
    
    adminpass=$(whiptail --passwordbox "Enter an admin password" 8 60 3>&1 1>&2 2>&3)
    if [[ -z "${adminpass// }" ]]; then
        printf "${BIRed}No user password given - aborting${BIWhite}\r\n"; exit
    fi
    
    adminpass2=$(whiptail --passwordbox "Confirm admin password" 8 60 3>&1 1>&2 2>&3)
    if  [ $adminpass2 == "" ]; then
        printf "${BIRed}No password confirmation given - aborting${BIWhite}\r\n"; exit
    fi
    if  [ $adminpass != $adminpass2 ]; then
        printf "${BIRed}Passwords don't match - aborting${BIWhite}\r\n"; exit
    fi
fi

if [[ $MYMENU == *"passwords"* ]]; then
    echo "Update your PI password"
    sudo passwd pi
    echo "Update your ROOT password"
    sudo passwd root
fi

#if [[ $MYMENU == *"prereq"* ]]; then
#fi

if [[ $MYMENU == *"securing"* ]]; then
    # Step 1: create the sysadmin account?
    if (whiptail --title "Create sysadmin account" --yesno "Do you want to create the sysadmin account?" 8 78); then
        echo "User selected Yes, exit status was $?."
        ADMINNAM=sysadmin
        USERID=$(logname)

        if [ $USERID == $ADMINNAME ]; then
            echo "User is already sysadmin"
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

        echo "New user will be added to the following groups: $NEW_GROUPS"

        useradd --groups ${NEW_GROUPS} --shell ${SRC_SHELL} --create-home ${DEST}
        mkhomedir_helper ${DEST}
        passwd ${DEST}

        printstatus "Please consider deleting the $userid account..."

    else
        echo "User selected No, exit status was $?."
    fi

    ## Step 2: Regenerate SSH Host keys
    printstatus "Regenerate SSH Host keys..."
    
    /bin/rm -v /etc/ssh/ssh_host_* 2>&1 | tee -a $LOGFILE
    dpkg-reconfigure openssh-server 2>&1 | tee -a $LOGFILE
    systemctl restart ssh 2>&1 | tee -a $LOGFILE

    ## Step 3:
       
fi

if [[ $MYMENU == *"showiplogon"* ]]; then
    printstatus "Make sure the IP address is shown at the logon screen."
    ## Backup issue file.
    cat /etc/issue >> /etc/issue.bak 2>&1 | tee -a $LOGFILE

    ## Get content and add info to issue file.
    cat /etc/issue > worker_file 2>&1 | tee -a $LOGFILE
    #echo "" >> worker_file 2>&1 | tee -a $LOGFILE
    echo 'IP Address: \4{ens33}' >> worker_file 2>&1 | tee -a $LOGFILE
    echo "" >> worker_file 2>&1 | tee -a $LOGFILE
    #echo "" >> worker_file

    ## Replace the contend of the issue file.
    cat worker_file > /etc/issue 2>&1 | tee -a $LOGFILE

    ## Remove the worker file.
    rm worker_file 2>&1 | tee -a $LOGFILE

	#if [[ $MYMENU == *"hwsupport"* ]]; then
	#	sudo apt-get install $AQUIET -y i2c-tools 2>&1 | tee -a $LOGFILE
	#fi
fi

if [[ $MYMENU == *"hostRename"* ]]; then
    ## Format the date and time strings 
    current_time=$(date "+%Y%m%d-%H%M%S")
    RDM="$(date +"%3N")"

    . /etc/os-release
    OPSYS=${ID^^}
    #echo -e OPSYS: $OPSYS

    ## Get the last 4 characters of the MAC Address
    MAC=$(ifconfig | grep ether | tr -d ":" | awk '{print $2}' | tail -c 5)
    #echo -e MAC: $MAC

    ## The current and to be old name:
    OLDNAME="$(uname -n)"
    NEWNAME=$OPSYS$RDM${MAC^^}
    #echo -e $NEWNAME

    ## Set the new hostname.
    hostnamectl set-hostname $NEWNAME

    ## Update the /etc/hosts file.
    if grep -Fq "127.0.1.1" /etc/hosts
        then
            # code if found
            # Replace the line
            sed -i "/127.0.1.1/c\127.0.1.1    $NEWNAME" /etc/hosts
        else
            # code if not found
            # Add the line
            echo '127.0.1.1    '$NEWNAME &>> /etc/hosts
    fi

    ## Check if Ubuntu Cloud config is used
    cloudFile="/etc/cloud/cloud.cfg"
    if [ -f "$cloudFile" ]
        then
            # code if found
            sed -i "/preserve_hostname/c\preserve_hostname: true" $cloudFile
    fi
fi

if [[ $MYMENU == *"installPulseAgent"* ]]; then

    ## TEST CONNECTION TO YOUR PULSE INSTANCE"
    PULSEINSTANCE=$(whiptail --inputbox "Enter your Pulse Console Instance (for example iotc001,iotc002, etc.)" 8 60 $PULSEINSTANCE 3>&1 1>&2 2>&3)
    PULSEADDENDUM="-pulse.vmware.com"
    echo $PULSEINSTANCE 2>&1 | tee -a $LOGFILE
    PULSEHOST="$PULSEINSTANCE$PULSEADDENDUM"
    echo $PULSEHOST 2>&1 | tee -a $LOGFILE
    PULSEPORT=443
    TIMEOUT=1
    if nc -w $TIMEOUT -z $PULSEHOST $PULSEPORT; then
        echo "CONNECTION SUCCESSFUL!"  2>&1 | tee -a $LOGFILE
        echo "Connection to the Pulse Server ${PULSEHOST} was Successful" 2>&1 | tee -a $LOGFILE
    else
        echo "CONNECTION FAILED!" 2>&1 | tee -a $LOGFILE
        echo "Connection to the Pulse Server ${PULSEHOST} Failed" 2>&1 | tee -a $LOGFILE
        echo "Please Confirm if the Pulse URL is correct" 2>&1 | tee -a $LOGFILE
        echo "If the Pulse URL is correct, then please ensure that we can open an outbound HTTPS connection to the Pulse Server over port 443" 2>&1 | tee -a $LOGFILE
        exit 1
    fi

    ## Determine CPU Architecture:
    CPUARCH=$(lscpu | grep Architecture | tr -d ":" | awk '{print $2}')
    echo $CPUARCH 2>&1 | tee -a $LOGFILE
    echo $CPUARCH
    ## Prep download
    mkdir /home/pulseagent
    PULSEAGENTX86="/api/iotc-agent/iotc-agent-x86_64-2.0.0.548.tar.gz"
    PULSEAGENTARM="/api/iotc-agent/iotc-agent-arm-2.0.0.548.tar.gz"
    PULSEAGENTARM64="/api/iotc-agent/iotc-agent-aarch64-2.0.0.548.tar.gz"
    PULSEURLX86="https://$PULSEHOST$PULSEAGENTX86"
    PULSEURLARM="https://$PULSEHOST$PULSEAGENTARM"
    PULSEURLARM64="https://$PULSEHOST$PULSEAGENTARM64"

    if [[ $CPUARCH == *"x86_64"* ]];then
        curl -o /home/pulseagent/pulseagent.tar.gz $PULSEURLX86 2>&1 | tee -a $LOGFILE
        elif [[ $CPUARCH == *"armv7l"* ]];then
            curl -o /home/pulseagent/pulseagent.tar.gz $PULSEURLARM 2>&1 | tee -a $LOGFILE
        elif [[ $CPUARCH == *"ARMv8"* ]];then
            curl -o /home/pulseagent/pulseagent.tar.gz $PULSEURLARM64 2>&1 | tee -a $LOGFILE
        else
            printl "${BIRed}By the look of it, not one of the supported CPU Architecture - aborting${BIWhite}\r\n"; exit 2>&1 | tee -a $LOGFILE
    fi

    chmod -R 777 /home/pulseagent

    ## UNZIPPING THE AGENT
    tar -xzf /home/pulseagent/pulseagent.tar.gz -C /home/pulseagent
    chmod -R 777 /home/pulseagent
    
    ## INSTALLING THE AGENT
    /home/pulseagent/iotc-agent/install.sh 2>&1 | tee -a $LOGFILE
    echo "" 2>&1 | tee -a $LOGFILE
    echo "Installed the Agent" 2>&1 | tee -a $LOGFILE
    echo "The Agent is installed at /opt/vmware/iotc-agent" 2>&1 | tee -a $LOGFILE
    echo "" 2>&1 | tee -a $LOGFILE
fi

#if [[ $MYMENU == *"menu_option_05"* ]]; then
#fi

#if [[ $MYMENU == *"menu_option_06"* ]]; then
#fi

if [[ $MYMENU == *"log2ram"* ]]; then
    printstatus "Installing Log2Ram"
    cd
	git clone https://github.com/azlux/log2ram.git 2>&1 | tee -a $LOGFILE
    cd log2ram
    chmod +x install.sh
    sudo ./install.sh 2>&1 | tee -a $LOGFILE
	cd
fi

##
## Some cleanup at the end...
##
rm -rf /var/cache/apt/archives/apt-fast
apt-get $AQUIET -y clean 2>&1 | tee -a $LOGFILE

printstatus "All done."
printf "${BIGreen}== ${BIYELLOW}When complete, remove the script from the /home/pi directory.\r\n"
printf "${BIGreen}==\r\n"
printf "${BIGreen}== ${BIPurple}Current IP: %s${BIWhite}\r\n" "$myip"
echo -e Current IP: $myip  Hostname: $NEWNAME >> $LOGFILE
echo -e Hostname: $newhostname >> $LOGFILE
printstatus  "ALL DONE - PLEASE REBOOT NOW"