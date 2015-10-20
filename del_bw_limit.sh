#!/bin/bash
# removes filters / limits from all guests
  
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
    tc qdisc del dev ${IFB} root
    tc filter del dev ${iface} parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ${IFB}
    ip link delete dev ${IFB}
    tc qdisc del dev ${iface} ingress
    tc qdisc del dev ${iface} root
done
