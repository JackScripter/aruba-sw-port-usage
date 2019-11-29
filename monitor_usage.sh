#!/bin/bash
# SETTINGS
# List of host to check
CHECK_HOST=("coresw1" "sw1" "sw2")
# Host portmap files. Specifie the name of each file.
HOST_PORTMAP=("/scripts/portmap_coresw1" "/scripts/portmap_sw1" "/scripts/portmap_sw2")

# Generate table of interface mapped to OID.
function GenIntTable() {
	interface=`snmpwalk -v 3 -a SHA -A *** -x AES -X *** -u *** -l Authpriv $currentHost iso.3.6.1.2.1.2.2.1.2 -P e 2> /dev/null`
	interface=`echo "$interface" | cut -d'.' -f 11 | sed 's/STRING://g' | tr -s ' '`
	echo "$interface" >> portmap_$currentHost
}
# Get average usage ingress traffic on ports
function AvgPortIn() {
	usageIn=`snmpwalk -v 3 -a SHA -A *** -x AES -X *** -u *** -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil -P e 2> /dev/null`
	usageIn=`echo "$usageIn" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
	echo "$usageIn"
}
# Get average usage outgress traffic on ports
function AvgPortOut() {
        usageOut=`snmpwalk -v 3 -a SHA -A *** -x AES -X *** -u *** -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil -P e 2> /dev/null`
        usageOut=`echo "$usageOut" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
        echo "$usageOut"
}
function AvgPort() {
	usageIn=`snmpwalk -v 3 -a SHA -A *** -x AES -X *** -u *** -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil -P e 2> /dev/null`
        usageIn=`echo "$usageIn" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgInPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
	usageOut=`snmpwalk -v 3 -a SHA -A *** -x AES -X *** -u *** -l Authpriv $currentHost STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil -P e 2> /dev/null`
        usageOut=`echo "$usageOut" | sed 's/STATISTICS-MIB::hpSwitchPortStatAvgOutPortUtil.//g' | sed 's/INTEGER://g' | tr -s ' '`
        echo "$usageIn"
	echo "$usageOut"
}
# Map port and returned value
function Map() {
	while IFS= read -r avgIn; do
                avgInID=`echo "$avgIn" | cut -d' ' -f1`                                 # Port ID
                avgIn=`echo "$avgIn" | cut -d' ' -f3`                                   # Port usage ingress
		avgOut=`echo -e "$usageAvgOut" | grep ^"${avgInID} =" | cut -d' ' -f3`
                port=`cat $currentPortmap | grep ^"${avgInID} =" | cut -d '"' -f2`      # Interface

                mapped=`echo "$port;$avgIn;$avgOut"`
		influx -host IP -username *** -password '***' -database switchPortUse -execute "INSERT portUse,port=$port switch=\"$currentHost\",in=$avgIn,out=$avgOut"
        done < <(printf '%s\n' "$usageAvg")
}
for i in "${!CHECK_HOST[@]}"; do
	currentPortmap=`echo ${HOST_PORTMAP[$i]}`
	currentHost=`echo ${CHECK_HOST[$i]}`

	usageAvg=`AvgPortIn`	# output: portID = int (61 = 11)
	usageAvgOut=`AvgPortOut`
	Map
done
#GenIntTable
