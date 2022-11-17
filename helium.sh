#!/bin/bash
#script by Abi Darwish

set -e

VERSIONNAME="Helium v"
VERSIONNUMBER="1.0"
GREEN='\e[1;32m'
RED='\e[;31m'
WHITE='\e[1m'
NOCOLOR='\e[0m'

providers="/etc/dnsmasq/providers.txt"
dnsmasqHostFinalList="/etc/dnsmasq/adblock.hosts"
tempHostsList="/etc/dnsmasq/list.tmp"

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
 	if [[ $(grep -w "ID_LIKE" /etc/os-release | awk -F'=' '{print $2}') != "debian" ]]; then
 		echo ""
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
    apt update
    apt install dnsmasq dnsutils
    mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    wget -q -O /etc/dnsmasq.conf "https://raw.githubusercontent.com/abidarwish/helium/main/dnsmasq.conf"
    wget -q -O ${providers} "https://raw.githubusercontent.com/abidarwish/helium/main/providers.txt"
    echo -e ${GREEN}"done"${NOCOLOR}
}

function listUpdate() {
    echo -e -n "Updating hostnames list..."
    > ${tempHostsList}
    while IFS= read -r line; do
        list_url=$(echo $line | cut -d '"' -f2)
        curl "${list_url}" 2> /dev/null | sed -E '/^!/d' | sed '/#/d' | sed -E 's/^\|\|/0.0.0.0 /g' | awk -F '^' '{print $1}' | grep -E "^0.0.0.0" | awk -F' ' '!a[$NF]++ {gsub(/^/,"0.0.0.0 ",$NF) ; print $NF ; gsub(/^(127|0)\.0\.0\.(0|1)/,"::1",$NF) ; print $NF}' | sed -E '/^0.0.0.0 0.0.0.0/d' | sed -E '/^::1 0.0.0.0/d' >> ${tempHostsList}
    done < ${providers}

    cat ${tempHostsList} | sed '/^$/d' | sort | uniq > ${dnsmasqHostFinalList}

    systemctl restart dnsmasq
    echo -e ${GREEN}"done"${NOCOLOR}
    sleep 1
    echo -e "$(cat ${dnsmasqHostFinalList} | wc -l) hostnames have been updated"
}

initialCheck

if [[ -e /etc/dnsmasq.conf ]]; then
    if [[ ! -e /etc/dnsmasq ]]; then
        mkdir -p /etc/dnsmasq
    fi
    clear
    header
    echo
    listUpdate
    echo
    exit 0
else
    if [[ ! -e /etc/dnsmasq ]]; then
        mkdir -p /etc/dnsmasq
    fi
    clear
    header
    echo
    install
    listUpdate
fi