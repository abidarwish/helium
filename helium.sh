#!/bin/bash
#script by Abi Darwish

set -e

VERSIONNAME="Helium v"
VERSIONNUMBER="1.2"
GREEN="\e[1;32m"
RED="\e[1;31m"
WHITE="\e[1m"
NOCOLOR="\e[0m"

providers="/etc/dnsmasq/providers.txt"
dnsmasqHostFinalList="/etc/dnsmasq/adblock.hosts"
tempHostsList="/etc/dnsmasq/list.tmp"

publicIP=$(wget -qO- ipv4.icanhazip.com)

function header() {
	echo -e $GREEN"$VERSIONNAME$VERSIONNUMBER" $NOCOLOR
	echo -e $WHITE"by Abi Darwish" $NOCOLOR
}

function isRoot() {
	if [ "${EUID}" != 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

function checkVirt() {
	if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
	fi

	if [ "$(systemd-detect-virt)" == "lxc" ]; then
		echo "LXC is not supported (yet)."
		exit 1
	fi
}

function checkOS() {
 	if [[ $(grep -w "ID" /etc/os-release | awk -F'=' '{print $2}') -ne "debian" ]] || [[ $(grep -w "ID" /etc/os-release | awk -F'=' '{print $2}') -ne "ubuntu" ]]; then
        	clear
        	header
 		echo
 		echo -e ${RED}"Your OS is not supported. Please use Debian/Ubuntu"$NOCOLOR
 		echo ""
 		exit 1
	fi
}

function initialCheck() {
	isRoot
	checkVirt
	checkOS
}

function install() {
    echo -e -n "Installing..."
    if [[ ! -e /etc/dnsmasq ]]; then
    	mkdir -p /etc/dnsmasq
    fi
    cp /etc/resolv.conf /etc/resolv.conf.bak
    if [[ $(lsof -i :53 | grep -w -c "systemd-r") -ge "1" ]]; then
    	systemctl disable systemd-resolved
	systemctl stop systemd-resolved
	unlink /etc/resolv.conf
	echo nameserver 127.0.0.1 | tee /etc/resolv.conf
    fi
    apt update
    apt install dnsmasq dnsutils
    mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    wget -q -O /etc/dnsmasq.conf "https://raw.githubusercontent.com/abidarwish/helium/main/dnsmasq.conf"
    sed -i "s/YourPublicIP/${publicIP}/" /etc/dnsmasq.conf
    wget -q -O ${providers} "https://raw.githubusercontent.com/abidarwish/helium/main/providers.txt"
    > ${tempHostsList}
    while IFS= read -r line; do
        list_url=$(echo $line | cut -d '"' -f2)
        curl "${list_url}" 2> /dev/null | sed -E '/^!/d' | sed '/#/d' | sed -E 's/^\|\|/0.0.0.0 /g' | awk -F '^' '{print $1}' | grep -E "^0.0.0.0" | awk -F' ' '!a[$NF]++ {gsub(/^/,"0.0.0.0 ",$NF) ; print $NF ; gsub(/^(127|0)\.0\.0\.(0|1)/,"::1",$NF) ; print $NF}' | sed -E '/^0.0.0.0 0.0.0.0/d' | sed -E '/^::1 0.0.0.0/d' >> ${tempHostsList}
    done < ${providers}

    cat ${tempHostsList} | sed '/^$/d' | sort | uniq > ${dnsmasqHostFinalList}

    systemctl restart dnsmasq
    clear
    header
    echo
    echo -e ${GREEN}"Installation completed"${NOCOLOR}
    echo -e "Type \e[1;32mhelium\e[0m to start"
    echo
    exit 0
}

function start() {
	clear
	header
	echo
	if [[ $(systemctl is-active dnsmasq) == "active" ]]; then
		echo -e $GREEN"Helium is already running"$NOCOLOR
		echo
		read -p $'Press Enter to continue...'
		mainMenu
	fi
	systemctl restart dnsmasq
	sleep 2
	echo -e -n "Starting Helium..."
	echo -e $GREEN"done"$NOCOLOR
	echo
	read -p $'Press Enter to continue...'
	mainMenu
}

function stop() {
	clear
	header
	echo
	if [[ $(systemctl is-active dnsmasq) == "active" ]]; then
		echo -e $GREEN"Helium is running"$NOCOLOR
		echo
		read -p "Are you sure to stop Helium? [y/n]: " STOP
		if [[ $STOP == "y" ]]; then
			systemctl stop dnsmasq
			echo -e -n "Stopping Helium..."
			sleep 2
			echo -e $GREEN"done"$NOCOLOR
			echo
			read -p "Press Enter to continue..."
			mainMenu
		else
			echo -e "Helium is not stopped"
			echo
			read -p "Press Enter to continue..."
			mainMenu
		fi
	else
		echo -e $RED"Helium is already stopped"$NOCOLOR
		echo
		read -p "Press Enter to continue..."
		mainMenu
	fi
}

function changeDNS() {
        clear
        header
        echo
        echo -e "Proxy server IP address to bypass Netflix"
        read -p "(press c to cancel): " DNS
        oldDNS=$(grep -E -w "^server" /etc/dnsmasq.conf | cut -d '=' -f2)
        if [[ $DNS == "c" ]]; then
            mainMenu
        fi
        if [[ -z $DNS ]]; then
            changeDNS
        fi
        sed -i "s/server=${oldDNS}/server=${DNS}/" /etc/dnsmasq.conf
        sleep 1
        echo -e -n "DNS server has been changed to "
        echo -e $GREEN"$DNS"$NOCOLOR
        echo
        read -p "Press Enter to continue..."
        mainMenu
}

function uninstall() {
	clear
	header
	echo
	read -p "Are you sure to uninstall Helium? [y/n]: " UNINSTALL
	if [[ $UNINSTALL == "y" ]]; then
		systemctl stop dnsmasq
		systemctl disable dnsmasq
		apt autoremove --purge dnsmasq 2>&1
		rm -rf /etc/dnsmasq
		echo -e -n "Uninstalling Helium..."
		sleep 2
		echo -e $GREEN"done"$NOCOLOR
		echo
		exit 0
	else
		echo -e "Helium is not removed"
		echo
		read -p "Press Enter to continue..."
		mainMenu
	fi
}

function listUpdate() {
    clear
    header
    echo
    echo -e -n "Updating hostnames..."
    wget -q -O ${providers} "https://raw.githubusercontent.com/abidarwish/helium/main/providers.txt"
    > ${tempHostsList}
    while IFS= read -r line; do
        list_url=$(echo $line | cut -d '"' -f2)
        curl "${list_url}" 2> /dev/null | sed -E '/^!/d' | sed '/#/d' | sed -E 's/^\|\|/0.0.0.0 /g' | awk -F '^' '{print $1}' | grep -E "^0.0.0.0" | awk -F' ' '!a[$NF]++ {gsub(/^/,"0.0.0.0 ",$NF) ; print $NF ; gsub(/^(127|0)\.0\.0\.(0|1)/,"::1",$NF) ; print $NF}' | sed -E '/^0.0.0.0 0.0.0.0/d' | sed -E '/^::1 0.0.0.0/d' >> ${tempHostsList}
    done < ${providers}

    cat ${tempHostsList} | sed '/^$/d' | sort | uniq > ${dnsmasqHostFinalList}

    systemctl restart dnsmasq
    echo -e ${GREEN}"done"${NOCOLOR}
    sleep 1
    echo -e -n $GREEN"$(cat ${dnsmasqHostFinalList} | wc -l) "$NOCOLOR
    echo -e "hostnames have been updated"
    echo
    read -p "Press Enter to continue..."
    mainMenu
}

function mainMenu() {
	clear
	header
	echo
	echo -e "What do you want to do?
[1] Start Helium
[2] Stop Helium
[3] Update hostnames
[4] Bypass Netflix
[5] Uninstall Helium
[6] Exit"
	echo
	read -p $'Enter option [1-6]: ' MENU_OPTION
	case ${MENU_OPTION} in
	1)
	    	start
	   	;;
	2)
		stop
		;;
   	3)
		listUpdate
		;;
        4)
                changeDNS
                ;;
	5)
		uninstall
		;;
	6)
		exit 0
		;;
	*)
	mainMenu
	esac
}

initialCheck

if [[ ! -z $(which dnsmasq) ]] && [[ -e /etc/dnsmasq ]]; then
	mainMenu
else
	clear
	header
        echo
	install
fi
