#!/bin/bash
# SETTINGS
# Policy Passphrase
POLICY_PASS='secret123'
# Authentication protocol passphrase
AUTH_PASS='secret123'
# SNMPv3 username
SNMP_USER='user1'
# Slack API Link
SLACK_API=''
# Ingress and Outgress threshold before sending notification
IN_TRESH=95
OUT_TRESH=95
# List of host to check
CHECK_HOST=("sw1" "sw2" "sw3")
# Host portmap files. Specifie the name of each file.
HOST_PORTMAP=("/scripts/portmap_sw1" "/scripts/portmap_sw2" "/scripts/portmap_sw3")
# Exclude list
EXCLUDE_PORT=(
"sw1" "2/C4,2/E16,2/B22,1/C8"
"sw3" "1/20,2/13,3/17,4/10"
)

# Notification function
function Notif() {
	msg=`echo -e "Port: ${port}@${mode} have reach limit threshold. Port usage is ${avgIn}%"`
	curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"[$currentHost] $msg\"}" "$SLACK_API"
}
# Generate table of interface mapped to OID.
function GenIntTable() {
	interface=`snmpwalk -v 3 -a SHA -A $AUTH_PASS -x AES -X $POLICY_PASS -u $SNMP_USER -l Authpriv $currentHost iso.3.6.1.2.1.2.2.1.2 -P e 2> /dev/null`
	interface=`echo "$interface" | cut -d'.' -f 11 | sed 's/STRING://g' | tr -s ' '`
	echo "$interface" >> portmap_$currentHost
}
# Get average usage ingress traffic on ports
function AvgPortIn() {
	usageIn=`snmpwalk -v 3 -a SHA -A $AUTH_PASS -x AES -X $POLICY_PASS -u $SNMP_USER -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil -P e 2> /dev/null`
	usageIn=`echo "$usageIn" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
	echo "$usageIn"
}
# Get average usage outgress traffic on ports
function AvgPortOut() {
        usageOut=`snmpwalk -v 3 -a SHA -A $AUTH_PASS -x AES -X $POLICY_PASS -u $SNMP_USER -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil -P e 2> /dev/null`
        usageOut=`echo "$usageOut" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
        echo "$usageOut"
}
# Map port and returned value
function Map() {
	while IFS= read -r avgIn; do
		avgInID=`echo "$avgIn" | cut -d' ' -f1`					# Port ID
		avgIn=`echo "$avgIn" | cut -d' ' -f3`					# Port usage ingress
		port=`cat $currentPortmap | grep ^"${avgInID} =" | cut -d '"' -f2`	# Interface

		# Skip excluded ports
		for ((h=0; h<${#EXCLUDE_PORT[@]}; h++)); do if [ $(( $h % 2 )) == 0 ] && [[ "${EXCLUDE_PORT[$h]}" == "$currentHost" ]] && [[ "${EXCLUDE_PORT[$(($h+1))]}" =~ "$port" ]]; then continue 2; fi; done

		mapped=`echo "$port;$avgIn"`
		case $mode in
			"in")
				if [[ $avgIn -gt $IN_TRESH ]]; then Notif; fi ;;
			"out")
				if [[ $avgIn -gt $OUT_TRESH ]]; then Notif; fi ;;
		esac
	done < <(printf '%s\n' "$usageAvg")
}

for i in "${!CHECK_HOST[@]}"; do
	currentPortmap=`echo ${HOST_PORTMAP[$i]}`
	currentHost=`echo ${CHECK_HOST[$i]}`

	usageAvg=`AvgPortIn`
	mode="in"
	Map
	usageAvg=`AvgPortOut`
	mode="out"
	Map
done
#GenIntTable
