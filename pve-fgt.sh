#!/bin/bash

# Take one argument from the commandline: VM name
if ! [ $# -eq 3 ]; then
    echo "Usage: $0 <node-name> <IP ADDRESS> <GATEWAY>"
    exit 1
fi

# Directory to store images
DIR=/home

# Location of cloud image
IMAGE=/var/lib/vz/template/iso/fortios7.4beta3.img

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
    mkdir -p cfg-drv-fgt/openstack/latest/
    mkdir -p cfg-drv-fgt/openstack/content/

cat >cfg-drv-fgt/openstack/content/0000 <<EOF
-----BEGIN FGT VM LICENSE-----
...
-----END FGT VM LICENSE-----
EOF

cat >cfg-drv-fgt/openstack/latest/user_data <<EOF
config system interface
  edit "port1"
    set vdom "root"
    set mode static
    set ip $IPADDR/24
    set allowaccess ping https ssh snmp http     
  next
end
config system dns
  set primary 223.5.5.5
  set secondary 223.5.5.5
end
config router static
  edit 0
    set gateway $GATEWAY
    set device "port1"
  next
end
config system global
  set admintimeout 480
  set hostname FGT-VM64-KVM-$1
end
EOF



    echo "$(date -R) Create VM..."
    qm create $1 --name "FGT-cloudinit-$1" --memory $MEM --cores $CPUS --net0 virtio,bridge=$BRIDGE >> $1.log
    echo "$(date -R) Import image..."
    cp $IMAGE $DISK >> $1.log
    qm importdisk $1 $DISK local-lvm >> $1.log
    echo "$(date -R) Link disk..."
    qm set $1 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$1-disk-0 >> $1.log
    # echo "$(date -R) Resize disk..."
    # qm disk resize $1 scsi0 60G >> $1.log
    echo "$(date -R) Set boot option..."
    qm set $1 --boot c --bootdisk scsi0 >> $1.log
    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    genisoimage -J -R -V config2 -o $CI_ISO cfg-drv-fgt &>> $1.log
    qm importdisk $1 $1-cidata.iso local-lvm >> $1.log
    echo "$(date -R) Set cloudinit..."
    qm set $1 --cdrom local-lvm:vm-$1-disk-1 >> $1.log
    qm set $1 --agent enabled=1 >> $1.log
    # Create logdisk 10G
    echo "$(date -R) Create logdisk 10G"
    qemu-img create -f qcow2 log.qcow2 10G >>$1.log
    qm importdisk $1 log.qcow2 local-lvm >>$1.log
    echo "$(date -R) Link log disk..."
    qm set $1 --scsihw virtio-scsi-pci --scsi1 local-lvm:vm-$1-disk-2 >> $1.log

    # # Eject cdrom
    # echo "$(date -R) Cleaning up cloud-init..."
    # qm disk unlink $1 --idlist ide2 >> $1.log

    # Remove the unnecessary cloud init files
    rm $CI_ISO $DISK log.qcow2 >> $1.log
    rm -rf cfg-drv-fgt >>$1.log

    echo "$(date -R) Start VM$1..."
    qm start $1 >> $1.log

    echo "$(date -R) DONE. SSH to $1 using $IP with  username 'ubuntu'."

popd > /dev/null