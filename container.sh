#!/bin/sh

echo " Container Creator"
echo " ---------------- "
echo "1" > /proc/sys/net/ipv4/ip_forward
#<READING PARAMS>

#init variables 

CONTAINER_HOSTNAME="Dummy container"
CONTAINER_IP="172.17.0.2"
CONTAINER_RFS=""

while getopts ":i:r:h:" opt;
do 
   case ${opt} in 
   
   h) 
      echo "optarg = $OPTARG"
      if [ ! -z "$OPTARG" ]
        then 
          echo "imed aouidene"
          CONTAINER_HOSTNAME="$OPTARG"
      else
          echo "$0$OPTARG is not a valid hostname">&2 
          exit
      fi
      ;;
   i)
      if [ ! -z "$OPTARG" ]
        then 
           CONTAINER_IP="$OPTARG"
      else
        echo "$0$OPTARG is not a valid ip">&2 
        exit
      fi
      ;;
   r)
      if [ ! -z "$OPTARG" ]
      then 
           CONTAINER_RFS="$OPTARG"
      else
        echo "$0$OPTARG is not a valid root filesystem" >&2 
        exit
      fi
      ;;

   :) 
      echo "$0 must supply argument to the -$OPTARG"
      exit 1 
      ;;
   esac 
done
# </READING PARAMS>

echo "hostname = $CONTAINER_HOSTNAME"
echo "container ip = $CONTAINER_IP"
echo "root FS= $CONTAINER_RFS"

if [ -z "$CONTAINER_HOSTNAME" ] || [ -z "$CONTAINER_IP" ] || [ -z "$CONTAINER_RFS" ]
  then
    #exit 1
     echo "required params" 
  else 
    echo "do all"
fi

#echo "forcing stop"
#exit 

sh -c "unshare --net --pid --uts --ipc --mount --fork sleep infinity" &


REFC=`pidof -s unshare`

echo "namespaces of ref conainter $REFC"

#sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'}

echo "Save namespaces" 


NET= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "net"
IPC= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "ipc"
MOUNT= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "mount"
PID= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "pid"
USER= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "user"
UTS= sh -c "ls -al /proc/$REFC/ns" | awk {'print $11'} | grep "uts"

# Optimize: Check if any existing bridges already exists 
EXISTS=`ip link show linsoft0 | wc -l`
if [ $EXISTS -eq 0 ]
then
echo "Creating linsoft0 bridge"


#sh -c 'ip link add name  linsoft0 type bridge'
sh -c 'brctl addbr linsoft0'

sh -c 'ip link set dev linsoft0  up'

sh -c "ip addr add 172.16.0.1/24 brd + dev linsoft0" 
#sh -c "ip route add default gw 192.168.0.1 dev linsoft0"

else
echo "Bridge already exists - skipping "

fi
rd="$RANDOM"
CETH0="ceth$rd"
HOSTETH0="heth$rd"
#echo "ADD the host interface"
#sh -c "ip link set dev enp0s3 master br1"

#echo "create a pair of cnx"
sh -c "ip link add name $HOSTETH0 type veth peer name $CETH0"

#echo "add the veth into the ref container"
sh -c "ip link set $CETH0 netns $REFC"

#echo "Add hosteth to the brigde"
#sh -c "ip link set $HOSTETH0 master linsoft0"
#echo "add addresse to the container"

sh -c "nsenter -t $REFC -n ip a add $CONTAINER_IP/24 dev $CETH0 "
sh -c "nsenter -t $REFC -n ip link set $CETH0 up"
sh -c "ip link set $HOSTETH0 up"
sh -c "brctl addif linsoft0 $HOSTETH0"


#-----------------------------------#
sh -c "mkdir -p /dev/writable-layer-$CREF"
sh -c "mkdir -p /dev/.work-$CREF"
sh -c "mkdir -p /rootfs-$CREF"
#--- delete those files ---#

#sh -c "echo 'rm -rf /dev/writable-layer-$REFC' > ~/delete-$REFC"
#sh -c "echo 'rm -rf /.work-$REFC' >> ~/delete-$REFC"
#sh -c "echo 'rm -rf /root-fs-$REFC' >> ~/delete-$REFC" 
#sh -c "chmod +x ~/delete-$REFC"
#sh -c "echo 'delete-$REFC' >> ~/allfiles "

sh -c "nsenter -t $REFC -p -i -u -m -n mount -t overlay -o lowerdir=$CONTAINER_RFS,upperdir=/dev/writable-layer-$CREF,workdir=/dev/.work-$CREF none /rootfs-$CREF"
#sh -c "nsenter -t $REFC -p -i -u -m -n mount"
#sh -c "nsenter -t $REFC -p -i -u -m -n mount $CONTAINER_RFS  /"
#sh -c "nsenter -t $REFC -p -i -u -m -n pivot_root $CONTAINER_RFS / "
#Mount proc 

sh -c "nsenter -t $REFC -p -i -u -m -n chroot $CONTAINER_RFS  mount -t proc none /proc"
sh -c "nsenter -t $REFC -p -i -u -m -n hostname $CONTAINER_HOSTNAME"
sh -c "nsenter -t $REFC -p -i -u -m -n ip route add default via 172.16.0.1"
sh -c "nsenter -t $REFC -p -i -u -m -n iptables -t nat -A POSTROUTING -s 172.16.0.0/24 ! -o linsoft0 -j MASQUERADE"


# entercontainer 

sh -c "nsenter -t $REFC -p -i -u -m -n chroot $CONTAINER_RFS /bin/sh"


