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
	>${TEMP_HOSTS_LIST}
	while IFS= read -r line; do
		LIST_URL=$(echo $line | grep -E -v "^#" | cut -d '"' -f2)
		curl "${LIST_URL}" 2>/dev/null | sed -E '/^!/d' | sed '/#/d' | sed '/<a/d' | sed -E 's/^\|\|/0.0.0.0 /g' | awk -F '^' '{print $1}' | sed '/^$/d' | sed 's/^0.0.0.0 //g' | sed 's/^127.0.0.1 //g' | sed 's/^/0.0.0.0 /g' | grep -E "^0.0.0.0" >>${TEMP_HOSTS_LIST}
	done <${PROVIDERS}
	[[ ! -z $(ip a | grep -w "inet6") ]] && grep -E "^0.0.0.0" ${TEMP_HOSTS_LIST} | sed -E 's/^0.0.0.0/::1/g' >>${TEMP_HOSTS_LIST}
	cat ${TEMP_HOSTS_LIST} | sed '/^$/d' | sed -E '/^0.0.0.0 0.0.0.0|^::1 0.0.0.0/d' | sort | uniq >${DNSMASQ_HOST_FINAL_LIST}
	[[ ! -e /etc/dnsmasq/whitelist.hosts ]] && touch /etc/dnsmasq/whitelist.hosts
	DATA=$(cat /etc/dnsmasq/whitelist.hosts)
	for HOSTNAME in ${DATA}; do
		sed -E -i "/0.0.0.0 ${HOSTNAME}/d" /etc/dnsmasq/adblock.hosts
                sed -E -i "/:: ${HOSTNAME}/d" /etc/dnsmasq/adblock.hosts
	done
	[[ ! -e /etc/dnsmasq/blacklist.hosts ]] && touch /etc/dnsmasq/blacklist.hosts
	DATA=$(cat /etc/dnsmasq/blacklist.hosts)
	for HOSTNAME in ${DATA}; do
		echo "0.0.0.0 ${HOSTNAME}" >>/etc/dnsmasq/adblock.hosts
		if [[ ! -z $(ip a | grep -w "inet6") ]]; then
			echo ":: ${HOSTNAME}" >>/etc/dnsmasq/adblock.hosts
		fi
	done
	systemctl restart dnsmasq
	echo -e ${GREEN}"done"${NOCOLOR}
	sleep 1
	echo -e -n $GREEN" $(cat ${DNSMASQ_HOST_FINAL_LIST} | sed '/^$/d' | wc -l) "$NOCOLOR
	echo -e "hostnames have been blocked"
}

updateEngine
