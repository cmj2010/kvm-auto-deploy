#!/bin/bash

# Take one argument from the commandline: VM name
if ! [ $# -eq 4 ]; then
    echo "Usage: $0 <node-name> <IP ADDRESS> <GATEWAY> <NET>"
    exit 1
fi

# Directory to store images
DIR=/home

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
BRIDGE=vmbr85

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
    qm stop $1 >> $1.log 2>&1
    qm destroy $1 >> $1.log 2>&1

    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key 
    cat > $USER_DATA << _EOF_
#cloud-config

system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: fortinet
chpasswd: { expire: False }

ssh_pwauth: True
timezone: Asia/Shanghai

_EOF_

    # create metada, todo no hardcode ip address

    cat > $META_DATA << _EOF_
instance-id: $1
local-hostname : ubuntu-$1
network-interfaces: |
  iface ens18 inet static
  address $IPADDR
  network $NET.0
  netmask 255.255.255.0
  broadcast $NET.255
  gateway $GATEWAY
  dns-nameservers 223.5.5.5

_EOF_

    echo "$(date -R) Create VM..."
    qm create $1 --name "ubuntu-2004-cloudinit-$1" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE >> $1.log
    echo "$(date -R) Import image..."
    cp $IMAGE $DISK >> $1.log
    qm importdisk $1 $DISK local-lvm >> $1.log
    echo "$(date -R) Link disk..."
    qm set $1 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$1-disk-0 >> $1.log
    echo "$(date -R) Resize disk..."
    qm disk resize $1 scsi0 60G >> $1.log
    echo "$(date -R) Set boot option..."
    qm set $1 --boot c --bootdisk scsi0 >> $1.log
    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    genisoimage -output $CI_ISO -volid cidata -joliet -r $USER_DATA $META_DATA &>> $1.log
    qm importdisk $1 $1-cidata.iso local-lvm >> $1.log
    echo "$(date -R) Set cloudinit..."
    qm set $1 --cdrom local-lvm:vm-$1-disk-1 >> $1.log
    qm set $1 --agent enabled=1 >> $1.log

    # # Eject cdrom
    # echo "$(date -R) Cleaning up cloud-init..."
    # qm disk unlink $1 --idlist ide2 >> $1.log

    # Remove the unnecessary cloud init files
    rm $USER_DATA $META_DATA $CI_ISO $DISK >> $1.log

    echo "$(date -R) Start VM$1..."
    qm start $1 >> $1.log

    echo "$(date -R) DONE. SSH to $1 using $IP with  username 'ubuntu'."

popd > /dev/null