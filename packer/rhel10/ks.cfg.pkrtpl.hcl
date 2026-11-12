# RHEL 10 kickstart for the home lab template. Rendered by Packer templatefile().
text
cdrom
eula --agreed
firstboot --disable
skipx

lang en_AU.UTF-8
keyboard us
timezone Australia/Sydney --utc

network --bootproto=dhcp --device=link --activate --onboot=yes --hostname=tmpl-rhel10

rootpw --lock
user --name=${username} --groups=wheel --password=${password} --plaintext

firewall --enabled --service=ssh
selinux --enforcing
services --enabled=sshd,vmtoolsd

zerombr
clearpart --all --initlabel
autopart --type=lvm --nohome

reboot --eject

%packages
@^minimal-environment
open-vm-tools
perl
python3
tar
%end

%post
echo "${username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${username}
chmod 0440 /etc/sudoers.d/${username}
%end
