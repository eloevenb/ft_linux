# Requirements
Gentoo live GUI iso in a virtual machine, with a 40GB disk attached to it, a nat network and a host only adapter

## 0.0 SSH connection
Connect into the VM, open tty1 (Host key + F1 if on virtualbox) and change the root password:
```
sudo passwd root
su -
```
Then start the sshd service to connect from the host machine 
```
rc-service sshd start
```
Now you can connect via SSH to be able to copy and paste scripts
```
ip a
ssh root@192.168.x.x
```

## 0.1 Clone repository
As root :
```
git clone https://github.com/eloevenb/ft_linux.git
cd ft_linux
chmod a+rx ./*.sh
```

## 1.0 Initialize the filesystems
Start as Root :
```
./1-setup-filesystems.sh
./2-directory-tree.sh
./3-lfs-user.sh
```
