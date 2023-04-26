#cloud-config
# Hostname management
hostname: ubuntu

system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: fortinet
chpasswd: { expire: False }

# 配置 sshd 允许使用密码登录
ssh_pwauth: True