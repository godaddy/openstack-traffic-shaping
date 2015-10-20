#!/bin/bash
# Adds limits to all running guests
  
# List all UUIDs on the box
UUIDS=$(virsh list --uuid)
  
# Loop through each UUID, get the interface device
for uid in $UUIDS
do
    iface=$(virsh domiflist $uid | tail -2 | cut -d ' ' -f 1 | head -1)
 
    # Remove the existing limits
    virsh domiftune $uid $iface --config --outbound 0,0,0
    virsh domiftune $uid $iface --live --outbound 0,0,0 > /dev/null 2>&1
 
    # Set the new limits
    IFB=${iface/tap/ifb}
    ROOT_ID1=$(printf "%04x" $RANDOM)
    ROOT_ID2=$(printf "%04x" $RANDOM)
    modprobe ifb numifbs=0
    ip link delete dev ${IFB}
    ip link add name ${IFB} type ifb
    ip link set ${IFB} up
    tc qdisc del dev ${iface} ingress
    tc qdisc add dev ${iface} handle ffff: ingress
    tc filter add dev ${iface} parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ${IFB}
    tc qdisc del dev ${IFB} root
    tc qdisc del dev ${iface} root
    tc qdisc add dev ${IFB} root handle ${ROOT_ID1}: htb default 30
    tc class add dev ${IFB} parent ${ROOT_ID1}: classid ${ROOT_ID1}:10 htb rate 101mbit
    tc class add dev ${IFB} parent ${ROOT_ID1}:10 classid ${ROOT_ID1}:20 htb rate 0.5mbit
    tc class add dev ${IFB} parent ${ROOT_ID1}:10 classid ${ROOT_ID1}:30 htb rate 100mbit
    tc filter add dev ${IFB} parent ${ROOT_ID1}: protocol ipv6 prio 10 u32 match ip protocol 0 1 police mtu 1 drop flowid :1
    tc filter add dev ${IFB} parent ${ROOT_ID1}: protocol ipv6 prio 10 u32 match ip protocol 1 1 police mtu 1 drop flowid :1
    tc filter add dev ${IFB} parent ${ROOT_ID1}: protocol ip prio 20 u32 match ip dport 5355 0xffff police mtu 1 drop flowid :1
    tc filter add dev ${IFB} parent ${ROOT_ID1}: prio 30 u32 match ip tos 0 0 police mtu 100 continue classid ${ROOT_ID1}:20
    tc qdisc add dev ${iface} root handle ${ROOT_ID2}: htb default 10
    tc class add dev ${iface} parent ${ROOT_ID2}: classid ${ROOT_ID2}:10 htb rate 100mbit
 
done
