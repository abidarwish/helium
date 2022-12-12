#!/bin/bash
#script by Abi Darwish

VERSIONNAME="Helium v"
VERSIONNUMBER="1.4"
GREEN="\e[1;32m"
RED="\e[1;31m"
WHITE="\e[1m"
NOCOLOR="\e[0m"

providers="/etc/dnsmasq/providers.txt"
dnsmasqHostFinalList="/etc/dnsmasq/adblock.hosts"
tempHostsList="/etc/dnsmasq/list.tmp"

publicIP=$(wget -qO- ipv4.icanhazip.com)

function header() {
	echo -e $GREEN" $VERSIONNAME$VERSIONNUMBER" $NOCOLOR
	echo -e -n " by "
	echo -e $WHITE"Abi Darwish" $NOCOLOR
}

function isRoot() {
	if [ "${EUID}" != 0 ]; then
		echo " You need to run this script as root"
		exit 1
	fi
}

function checkVirt() {
	if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo " OpenVZ is not supported"
		exit 1
	fi

	if [ "$(systemd-detect-virt)" == "lxc" ]; then
		echo " LXC is not supported (yet)."
		exit 1
	fi
}

function checkOS() {
 	if [[ $(grep -w "ID" /etc/os-release | awk -F'=' '{print $2}') -ne "debian" ]] || [[ $(grep -w "ID" /etc/os-release | awk -F'=' '{print $2}') -ne "ubuntu" ]]; then
		clear
        	header
 		echo
 		echo -e ${RED}" Your OS is not supported. Please use Debian/Ubuntu"$NOCOLOR
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
	echo -e " Installing Helium..."
    	if [[ ! -e /etc/dnsmasq ]]; then
    		mkdir -p /etc/dnsmasq
	fi
    	if [[ ! -e /etc/resolv.conf.bak ]]; then
       		cp /etc/resolv.conf /etc/resolv.conf.bak
    	fi
    	if [[ $(lsof -i :53 | grep -w -c "systemd-r") -ge "1" ]]; then
    		systemctl disable systemd-resolved
		systemctl stop systemd-resolved
		unlink /etc/resolv.conf
                echo "nameserver 1.1.1.1" > /etc/resolv.conf
    	fi
    	apt update && apt install -y dnsmasq dnsutils vnstat resolvconf
    	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
	rm -rf /etc/dnsmasq.conf
    	wget -q -O /etc/dnsmasq.conf "https://raw.githubusercontent.com/abidarwish/helium/main/dnsmasq.conf"
    	sed -i "s/YourPublicIP/${publicIP}/" /etc/dnsmasq.conf
	rm -rf ${providers}
    	wget -q -O ${providers} "https://raw.githubusercontent.com/abidarwish/helium/main/providers.txt"
	sleep 1
	updateEngine
        > /etc/resolvconf/resolv.conf.d/original
	echo "nameserver 127.0.0.1" > /etc/resolv.conf
        echo "nameserver 127.0.0.1" > /etc/resolvconf/resolv.conf.d/head
	#sed -i -E "/^exit 0/d" /etc/rc.local
    	#echo -e 'echo "nameserver 127.0.0.1" > /etc/resolv.conf
#exit 0' >> /etc/rc.local
	sleep 1
    	echo -e " Installation completed"
	sleep 1
    	echo -e " Type \e[1;32mhelium\e[0m to start"
    	echo
	exit 0
}

function start() {
	clear
	header
	echo
	if [[ $(systemctl is-active dnsmasq) == "active" ]]; then
		echo -e $GREEN" Helium is already running"$NOCOLOR
		echo
		read -p $' Press Enter to continue...'
		mainMenu
	fi
	systemctl restart dnsmasq
	sleep 2
	echo -e -n " Starting Helium..."
	echo -e $GREEN"done"$NOCOLOR
	echo
	read -p $' Press Enter to continue...'
	mainMenu
}

function stop() {
	clear
	header
	echo
	if [[ $(systemctl is-active dnsmasq) == "active" ]]; then
		echo -e $GREEN" Helium is running"$NOCOLOR
		echo
		read -p " Are you sure to stop Helium? [y/n]: " STOP
		if [[ $STOP == "y" ]]; then
			systemctl stop dnsmasq
			echo "nameserver 1.1.1.1" > /etc/resolv.conf
			echo -e -n " Stopping Helium..."
			sleep 2
			echo -e $GREEN"done"$NOCOLOR
			echo
			read -p " Press Enter to continue..."
			mainMenu
		else
			echo -e " Helium is not stopped"
			echo
			read -p " Press Enter to continue..."
			mainMenu
		fi
	else
		echo -e $RED" Helium is already stopped"$NOCOLOR
		echo
		read -p " Press Enter to continue..."
		mainMenu
	fi
}

function changeDNS() {
	clear
   	header
    	echo
    	echo -e " Proxy server IP address to bypass Netflix"
    	read -p " (press c to cancel): " DNS
    	oldDNS=$(grep -E -w "^server" /etc/dnsmasq.conf | cut -d '=' -f2)
    	if [[ $DNS == "c" ]]; then
        	mainMenu
    	fi
    	if [[ -z $DNS ]]; then
        	changeDNS
    	fi
    	sed -i "s/server=${oldDNS}/server=${DNS}/" /etc/dnsmasq.conf
        systemctl restart dnsmasq
    	sleep 1
    	echo -e -n " DNS server has been changed to "
    	echo -e $GREEN"$DNS"$NOCOLOR
    	echo
    	read -p " Press Enter to continue..."
    	mainMenu
}

function uninstall() {
	clear
	header
	echo
	read -p " Are you sure to uninstall Helium? [y/n]: " UNINSTALL
	if [[ $UNINSTALL == "y" ]]; then
		systemctl stop dnsmasq
		systemctl disable dnsmasq
		apt remove -y dnsmasq > /dev/null 2>&1
		rm -rf /etc/dnsmasq
                > /etc/resolvconf/resolv.conf.d/original
                > /etc/resolvconf/resolv.conf.d/head
		mv /etc/resolv.conf.bak /etc/resolv.conf
		echo -e -n " Uninstalling Helium..."
		sleep 2
		echo -e $GREEN"done"$NOCOLOR
		echo
		exit 0
	else
		echo -e " Helium is not removed"
		echo
		read -p " Press Enter to continue..."
		mainMenu
	fi
}

function updateEngine() {
	echo -e -n " Updating blocked hostnames..."
	> ${tempHostsList}
    	while IFS= read -r line; do
        	list_url=$(echo $line | grep -E -v "^#" | cut -d '"' -f2)
        	curl "${list_url}" 2> /dev/null | sed -E '/^!/d' | sed '/#/d' | sed -E 's/^\|\|/0.0.0.0 /g' | awk -F '^' '{print $1}' | grep -E "^0.0.0.0" >> ${tempHostsList}
    	done < ${providers}
    
    	grep -E "^0.0.0.0" ${tempHostsList} | sed -E 's/^0.0.0.0/::1/g' >> ${tempHostsList}

    	cat ${tempHostsList} | sed '/^$/d' | sed -E '/^0.0.0.0 0.0.0.0/d' | sed -E '/^::1 0.0.0.0/d' | sort | uniq > ${dnsmasqHostFinalList}

    	systemctl restart dnsmasq
    	echo -e ${GREEN}"done"${NOCOLOR}
    	sleep 1
    	echo -e -n $GREEN" $(cat ${dnsmasqHostFinalList} | wc -l) "$NOCOLOR
   	echo -e "hostnames have been blocked"
}

function listUpdate() {
    	clear
    	header
    	echo
    	updateEngine
    	echo
    	read -p " Press Enter to continue..."
    	mainMenu
}

function activateProvider() {
	clear
	header
	echo
	printf " ${WHITE}%-26s %10s${NOCOLOR}\n" "LIST PROVIDER" "STATUS"
	echo " --------------------------------------"
	while IFS= read -r line; do
		ACTIVE_PROVIDER=$(echo $line | grep -v -E "^#" | cut -d '=' -f1)
		INACTIVE_PROVIDER=$(echo $line | grep -E "^#" | cut -d '=' -f1 | sed -E 's/^#//g')
		if [[ $(echo $line | grep -v -c -E "^#") -gt 0 ]]; then
		 	printf " %-25s \e[1;32m%12s\e[0m\n" "${ACTIVE_PROVIDER}" "active"
		else
			printf " %-25s \e[1;31m%12s\e[0m\n" "${INACTIVE_PROVIDER}" "inactive"
		fi
	done < /etc/dnsmasq/providers.txt
	echo
	read -p " Select a provider to be activated
 (press c to cancel): " SELECT
    	if [[ $SELECT == c ]]; then
		if [[ ! -z $(diff -q /etc/dnsmasq/providers.txt /etc/dnsmasq/providers.tmp) ]]; then
			rm -rf /etc/dnsmasq/providers.tmp
			echo " Applying changes..."
			updateEngine
			echo
			read -p " Press Enter to continue..."
			mainMenu
		else
			mainMenu
		fi
    	fi
    	if [[ -z $SELECT ]]; then
        	activateProvider
    	fi
	if [[ $(grep -E -c -w "^#${SELECT}" /etc/dnsmasq/providers.txt) != 0 ]]; then
		cp /etc/dnsmasq/providers.txt /etc/dnsmasq/providers.tmp
		sed -E -i "s/^\#${SELECT}/${SELECT}/" /etc/dnsmasq/providers.txt
		echo -e -n " Activating $SELECT..."
		sleep 2
		echo -e ${GREEN}"done"${NOCOLOR}
		sleep 2
		activateProvider
	else
		echo -e " ${SELECT} is already active"
	fi
    	echo
    	read -p " Press Enter to continue..."
	activateProvider
}

function deactivateProvider() {
	clear
	header
	echo
	printf " ${WHITE}%-26s %10s${NOCOLOR}\n" "LIST PROVIDER" "STATUS"
	echo " --------------------------------------"
	while IFS= read -r line; do
		ACTIVE_PROVIDER=$(echo $line | grep -v -E "^#" | cut -d '=' -f1)
		INACTIVE_PROVIDER=$(echo $line | grep -E "^#" | cut -d '=' -f1 | sed -E 's/^#//g')
		if [[ $(echo $line | grep -v -c -E "^#") -gt 0 ]]; then
		 	printf " %-25s \e[1;32m%12s\e[0m\n" "${ACTIVE_PROVIDER}" "active"
		else
			printf " %-25s \e[1;31m%12s\e[0m\n" "${INACTIVE_PROVIDER}" "inactive"
		fi
	done < /etc/dnsmasq/providers.txt
	echo
	read -p " Select a provider to be deactivated
 (press c to cancel): " SELECT
    	if [[ $SELECT == c ]]; then
		if [[ ! -z $(diff -q /etc/dnsmasq/providers.txt /etc/dnsmasq/providers.tmp) ]]; then
			rm -rf /etc/dnsmasq/providers.tmp
			echo " Applying changes..."
			updateEngine
			echo
			read -p " Press Enter to continue..."
			mainMenu
		else
			mainMenu
		fi
    	fi
    	if [[ -z $SELECT ]]; then
        	deactivateProvider
    	fi
	if [[ $(grep -E -c -w "^#${SELECT}" /etc/dnsmasq/providers.txt) == 0 ]]; then
		cp /etc/dnsmasq/providers.txt /etc/dnsmasq/providers.tmp
		sed -E -i "s/^${SELECT}/\#${SELECT}/" /etc/dnsmasq/providers.txt
		#echo -e -n " Deactivating $SELECT..."
		#sleep 2
		#echo -e ${GREEN}"done"${NOCOLOR}
		#sleep 2
		deactivateProvider
	else
		echo -e " ${SELECT} is already inactive"
	fi
    	echo
    	read -p " Press Enter to continue..."
	deactivateProvider
}

function mainMenu() {
	clear
	header
	echo
	echo -e " \e[1mSystem Status\e[0m"
	if [[ $(systemctl is-active dnsmasq) == active ]]; then
        	printf " %-25s %1s \e[1;32m%7s\e[0m" "Dnsmasq" ":" "running"
		printf "\n %-25s %1s \e[1;32m%7s\e[0m" "Active since" ":" "$(systemctl status dnsmasq.service | grep -w "Active" | awk '{print $9,$10}')"
    	else
        	printf " %-25s %1s \e[1;31m%7s\e[0m" "Dnsmasq" ":" "stopped"
    	fi
     	NAMESERVER=$(grep -w -E "^server" /etc/dnsmasq.conf | head -n 1 | awk -F'=' '{print $2}')
     	printf "\n %-25s %1s \e[1;32m%7s\e[0m" "Nameserver" ":" "$NAMESERVER"
	printf "\n %-25s %1s \e[1;32m%'d\n\e[0m" "Blocked hostnames" ":" "$(cat ${dnsmasqHostFinalList} | wc -l)"
    	echo
	echo -e " \e[1mVPS Info\e[0m"
	CPU=$(cat /proc/cpuinfo | grep "model\|Model" | tail -n 1 | awk -F: '{print $2}' | cut -d " " -f2-4)
	CPU_CORE=$(lscpu | grep "CPU(s)" | head -n 1 | awk '{print $2}')
	CPU_MHZ=$(lscpu | grep "MHz" | head -n 1 | sed 's/ //g' | awk -F: '{print $2}' | cut -d. -f1)
	OS=$(cat /etc/os-release |grep "PRETTY_NAME" | awk -F\" '{print $2}')
	KERNEL=$(uname -r)
	RAM_USED=$(free -m | grep Mem: | awk '{print $3}')
	TOTAL_RAM=$(free -m | grep Mem: | awk '{print $2}')
	RAM_USAGE=$(echo "scale=2; ($RAM_USED / $TOTAL_RAM) * 100" | bc | cut -d. -f1)
	DATE=$(date | awk '{print $2,$3,$4,$5,$6}')
    	UPTIME=$(uptime -p | sed 's/,//g' | awk '{print $2,$3", "$4,$5}')
	DAILY_USAGE=$(vnstat -d --oneline | awk -F\; '{print $6}' | sed 's/ //')
	MONTHLY_USAGE=$(vnstat -m --oneline | awk -F\; '{print $11}' | sed 's/ //')
	if [[ ${CPU_CORE} == 1 ]]; then
	    printf " %-25s %1s %-7s\e[0m" "CPU (single core)" ":" "${CPU} @ ${CPU_MHZ}Mhz"
	else
	    printf " %-25s %1s %-7s\e[0m" "CPU (${CPU_CORE} cores)" ":" "${CPU} @ ${CPU_MHZ}Mhz"
	fi
	printf "\n %-25s %1s %-7s\e[0m" "OS Version" ":" "${OS}"
	printf "\n %-25s %1s %-7s\e[0m" "Kernel Version" ":" "${KERNEL}"
	printf "\n %-25s %1s %-7s\e[0m" "RAM Usage" ":" "${RAM_USED}MB / ${TOTAL_RAM}MB (${RAM_USAGE}%)"
	printf "\n %-25s %1s %-7s\e[0m" "Date" ":" "${DATE}"
    	printf "\n %-25s %1s %-7s\e[0m" "Uptime" ":" "${UPTIME}"
 	printf "\n %-25s %1s %-7s\e[0m" "IP Address" ":" "${publicIP}"
	printf "\n %-25s %1s %-7s\e[0m" "Daily Data Usage" ":" "${DAILY_USAGE}"
	printf "\n %-25s %1s %-7s\e[0m" "Monthly Data Usage" ":" "${MONTHLY_USAGE}"
	echo
	echo
	echo -e $WHITE" Manage Helium"$NOCOLOR
 	echo -e " [1] Start Dnsmasq\t   [5] Activate Provider 
 [2] Stop Dnsmasq\t   [6] Deactivate provider
 [3] Update hostnames\t   [7] Uninstall Helium
 [4] Bypass Netflix\t   [8] Exit"
	echo
	read -p $' Enter option [1-8]: ' MENU_OPTION
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
		activateProvider
		;;
    	6)
        	deactivateProvider
        	;;
	7)
		uninstall
		;;
	8)
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
