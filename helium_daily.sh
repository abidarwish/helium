#!/bin/bash
#script by Abi Darwish

GREEN="\e[1;32m"
RED="\e[1;31m"
WHITE="\e[1m"
NOCOLOR="\e[0m"

providers="/etc/dnsmasq/providers.txt"
dnsmasqHostFinalList="/etc/dnsmasq/adblock.hosts"
tempHostsList="/etc/dnsmasq/list.tmp"

function updateEngine() {
	echo -e -n " Updating blocked hostnames..."
	>${tempHostsList}
	while IFS= read -r line; do
		list_url=$(echo $line | grep -E -v "^#" | cut -d '"' -f2)
		curl "${list_url}" 2>/dev/null | sed -E '/^!/d' | sed '/#/d' | sed -E 's/^\|\|/0.0.0.0 /g' | sed 's/^127.0.0.1 //g' | awk -F '^' '{print $1}' | sed '/^$/d' | sed 's/^0.0.0.0 //g' | sed 's/^/0.0.0.0 /g' | grep -E "^0.0.0.0" >>${tempHostsList}
	done <${providers}
	[[ ! -z $(ip a | grep -w "inet6") ]] && grep -E "^0.0.0.0" ${tempHostsList} | sed -E 's/^0.0.0.0/::1/g' >>${tempHostsList}
	cat ${tempHostsList} | sed '/^$/d' | sed -E '/^0.0.0.0 0.0.0.0|^::1 0.0.0.0/d' | sort | uniq >${dnsmasqHostFinalList}
	[[ ! -e /etc/dnsmasq/whitelist.hosts ]] && touch /etc/dnsmasq/whitelist.hosts
	DATA=$(cat /etc/dnsmasq/whitelist.hosts)
	for HOSTNAME in ${DATA}; do
		sed -E -i "/${HOSTNAME}/d" /etc/dnsmasq/adblock.hosts
	done
	systemctl restart dnsmasq
	echo -e ${GREEN}"done"${NOCOLOR}
	sleep 1
	echo -e -n $GREEN" $(cat ${dnsmasqHostFinalList} | sed '/^$/d' | wc -l) "$NOCOLOR
	echo -e "hostnames have been blocked"
}

updateEngine
