# kvm-auto-deploy

## Useage

1. Create bridge on KVM before use this script

2. excute shell

```dotnetli
Usage: ./kvm-autodeploy <node-name> <IP ADDRESS> <GATEWAY> <NET>
```

## Manual deploy

1. Download cloud image from ubuntu
<https://cloud-images.ubuntu.com/>

```dotnetcli
wget https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img
```

2. Make image

```dotnetcli
qemu-img convert -f qcow2 -O qcow2 ubuntu-20.04-server-cloudimg-amd64.img root-disk.qcow2
```

3. userdata

```dotnetcli
echo "system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: fortinet
chpasswd: { expire: False }
hostname: fortinet

ssh_pwauth: True
" | tee userdata
```

4. metadata

```dotnetcli
echo "instance-id: ubuntu2
network-interfaces: |
  iface ens3 inet static
  address 192.168.85.76
  network 192.168.85.0
  netmask 255.255.255.0
  broadcast 192.168.85.255
  gateway 192.168.85.1
hostname: ubuntu2
" | tee metadata
```

5. no cloud cloudinit

```dotnetcli
genisoimage -output cloudinit.iso -V cidata -r -J user-data meta-data
```

6. start vm

```dotnetcli
virt-install \
  --name ubuntu2 \
  --vcpu=4 \
  --ram=8192 \
  --disk path=ubsrv2-root-disk.qcow2,device=disk,bus=virtio \
  --disk path=cloudinit.iso,device=cdrom \
  --os-type linux \
  --os-variant ubuntu20.04 \
  --virt-type kvm \
  --graphics none \
  --network bridge=br-85,model=virtio \
  --import
```
