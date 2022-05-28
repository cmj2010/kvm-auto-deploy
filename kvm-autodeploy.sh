#!/bin/bash

# Take one argument from the commandline: VM name
if ! [ $# -eq 4 ]; then
    echo "Usage: $0 <node-name> <IP ADDRESS> <GATEWAY> <NET>"
    exit 1
fi

# Check if domain already exists
virsh dominfo $1 > /dev/null 2>&1
if [ "$?" -eq 0 ]; then
    echo -n "[WARNING] $1 already exists.  "
    read -p "Do you want to overwrite $1 (y/[N])? " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        virsh destroy $1 > /dev/null
        virsh undefine $1 > /dev/null
    else
        echo -e "\nNot overwriting $1. Exiting..."
        exit 1
    fi
fi

# Directory to store images
DIR=/root

# Location of cloud image
IMAGE=$DIR/ubuntu-20.04-server-cloudimg-amd64.img

# Amount of RAM in MB
MEM=1024

# Number of virtual CPUs
CPUS=1

# Cloud init files
USER_DATA=user-data
META_DATA=meta-data
CI_ISO=$1-cidata.iso
DISK=$1.qcow2

# Bridge for VMs (default bridge)
BRIDGE=br-85

# Metadata IP GW NET
IPADDR=$2
GATEWAY=$3
NET=$4

# Start clean
rm -rf $DIR/$1
mkdir -p $DIR/$1

pushd $DIR/$1 > /dev/null

    # Create log file
    touch $1.log

    echo "$(date -R) Destroying the $1 domain (if it exists)..."

    # Remove domain with the same name
    virsh destroy $1 >> $1.log 2>&1
    virsh undefine $1 >> $1.log 2>&1

    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key 
    cat > $USER_DATA << _EOF_
#cloud-config
# Hostname management
hostname: $1

system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: fortinet
chpasswd: { expire: False }

ssh_pwauth: True

_EOF_

    # create metada, todo no hardcode ip address

    cat > $META_DATA << _EOF_
instance-id: $1
network-interfaces: |
  iface ens3 inet static
  address $IPADDR
  network $NET.0
  netmask 255.255.255.0
  broadcast $NET.255
  gateway $GATEWAY

_EOF_

    echo "$(date -R) Copying template image..."
    cp $IMAGE $DISK

    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    genisoimage -output $CI_ISO -volid cidata -joliet -r $USER_DATA $META_DATA &>> $1.log

    echo "$(date -R) Installing the domain and adjusting the configuration..."
    echo "[INFO] Installing with the following parameters:"
    echo "virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --network
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu20.04 --noautoconsole"

    virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk \
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --network \
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=ubuntu20.04 --noautoconsole

    MAC=$(virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}')

    # Eject cdrom
    echo "$(date -R) Cleaning up cloud-init..."
    virsh change-media $1 hda --eject --config >> $1.log

    # Remove the unnecessary cloud init files
    rm $USER_DATA $CI_ISO

    echo "$(date -R) DONE. SSH to $1 using $IP with  username 'ubuntu'."

popd > /dev/null