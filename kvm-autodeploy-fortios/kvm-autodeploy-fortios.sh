#!/bin/bash

# Take one argument from the commandline: VM name
if ! [ $# -eq 3 ]; then
    echo "Usage: $0 <node-name> <IP ADDRESS> <GATEWAY>"
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
IMAGE=$DIR/fortios705.qcow2

# Amount of RAM in MB
MEM=4096

# Number of virtual CPUs
CPUS=2

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
  set primary 114.114.114.114
  set secondary 223.5.5.5
end
config router static
  edit 2
    set gateway $GATEWAY
    set device "port1"
  next
end
config system global
  set admintimeout 480
  set hostname FGT-VM64-KVM
end
EOF

    echo "$(date -R) Copying template image..."
    cp $IMAGE $DISK

    # Create logdisk 10G
    qemu-img create -f qcow2 log.qcow2 10G

    # Create CD-ROM ISO with cloud-init config
    echo "$(date -R) Generating ISO for cloud-init..."
    # genisoimage -J -R -V config2 -o $CI_ISO cfg-drv-fgt &>> $1.log
    # FortiOS use clouddrive
    # https://cloudinit.readthedocs.io/en/latest/topics/datasources/configdrive.html
    mkisofs -J -R -V config2 -o $CI_ISO cfg-drv-fgt &>> $1.log

    echo "$(date -R) Installing the domain and adjusting the configuration..."
    echo "[INFO] Installing with the following parameters:"
    echo "virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --disk log.qcow2 --network
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=generic --noautoconsole"

    virt-install --import --name $1 --ram $MEM --vcpus $CPUS --disk \
    $DISK,format=qcow2,bus=virtio --disk $CI_ISO,device=cdrom --disk log.qcow2 --network \
    bridge=$BRIDGE,model=virtio --os-type=linux --os-variant=generic --noautoconsole

    MAC=$(virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}')

    # Eject cdrom
    echo "$(date -R) Cleaning up cloud-init..."
    virsh change-media $1 hda --eject --config >> $1.log

    # Remove the unnecessary cloud init files
    rm -rf cfg-drv-fgt $CI_ISO

    echo "$(date -R) DONE. SSH to $1 using $IP with  username 'admin'."

popd > /dev/null