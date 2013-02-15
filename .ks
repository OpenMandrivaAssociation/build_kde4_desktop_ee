timezone Europe/Moscow
auth --useshadow --enablemd5
selinux --disabled
firewall --enabled
firstboot --enabled
part / --size 8692

services --enabled=acpid,alsa,atd,avahi-daemon,prefdm,irqbalance,mandi,dbus,netfs,network,network-up,partmon,resolvconf,rpcbind,rsyslog,sound,udev-post,mandrake_everytime,crond
services --disabled=sshd,pptp,pppoe,ntpd,iptables,ip6tables,shorewall,nfs-server,mysqld,abrtd,mysql,postfix,cups

repo --name=Main       --baseurl=http://abf.rosalinux.ru/downloads/cooker/repository/x86_64/main/release

repo --name=Non-Free       --baseurl=http://abf.rosalinux.ru/downloads/cooker/repository/x86_64/non-free/release

repo --name=Restricted	--baseurl=http://abf.rosalinux.ru/downloads/cooker/repository/x86_64/restricted/release


%packages
#%include .///x86_64.mini.lst
%include .///x86_64kde.lst
#%include .///x86_64kde-server.lst

%end

%post

#sed -i 's!MandrivaLinux!ROSALinux!g' /etc/lsb-release
#sed -i 's!Mandriva!ROSA Desktop!g' /etc/lsb-release
#sed -i 's!2011.0!2012.1!g' /etc/lsb-release                                                                                                                                                            

#We user non-free version (like EE)
sed -i 's/Free/EE/' /etc/product.id
sed -i 's/One/EE/' /etc/product.id
sed -i 's/Free/EE/p' /etc/os-release

# adding messagebus user to workaround rpm ordering (eugeni)
#/usr/share/rpm-helper/add-user dbus 1 messagebus / /sbin/nologin
#/usr/share/rpm-helper/add-group dbus 1 messagebus

#/bin/chown root:messagebus /lib*/dbus-1/dbus-daemon-launch-helper
#/bin/chmod u+s,g-s /lib*/dbus-1/dbus-daemon-launch-helper

####### avahi workaround                                                                                        
#/usr/share/rpm-helper/add-user avahi 1 avahi /var/avahi /bin/false                                              
#/usr/share/rpm-helper/add-user avahi 1 avahi-autoipd /var/avahi /bin/false                                      
#/usr/share/rpm-helper/add-service avahi 1 avahi-daemon                                                          
#### end of it

echo "###################################### Make initrd symlink >> "
echo ""

/usr/sbin/update-alternatives --set mkinitrd /usr/sbin/mkinitrd-dracut
rm -rf /boot/initrd-*

# adding life user
/usr/sbin/adduser live
/usr/bin/passwd -d live
/bin/mkdir -p /home/live
/bin/cp -rfT /etc/skel /home/live/
/bin/chown -R live:live /home/live
# usermod -a -G cdrom live
# enable live user autologin
if [ -f /usr/share/config/kdm/kdmrc ]; then
#/bin/sed -i -e 's/.*AutoLoginEnable.*/AutoLoginEnable=true/g' -e #'s/.*AutoLoginUser.*/AutoLoginUser=live/g' /usr/share/config/kdm/kdmrc
sed -i -e 's/.*AutoLoginEnable.*/AutoLoginEnable=true/g' /usr/share/config/kdm/kdmrc
sed -i -e 's/.*AutoLoginUser.*/AutoLoginUser=live/g' /usr/share/config/kdm/kdmrc
fi

# ldetect stuff
/usr/sbin/update-ldetect-lst

# setting up network manager by default
# don't forget to change it

pushd /etc/sysconfig/network-scripts
for iface in eth0 wlan0; do
	cat > ifcfg-$iface << EOF
DEVICE=$iface
ONBOOT=yes
NM_CONTROLLED=yes
EOF
done
popd

systemctl enable NetworkManager.service
systemctl enable getty@.service

### TEMP WORKAROUND FOR MIMEAPPS LIST###
echo DELETING MIMEAPPS
rm -f /usr/share/applications/mimeapps.list
###

# default background
pushd /usr/share/mdk/backgrounds/
ln -s rosa-background.jpg default.jpg 
popd

# mtab
# pushd /etc/
# ln -sf /proc/mounts mtab
# popd

#####workaround for time###                                                                                                                                                                                        
# rm -rf /etc/sysconfig/clock                                                                                                                                                                                        
# rm -rf /etc/adjtime                                                                                                                                                                                                
# rm -rf /etc/localtime                                                                                                                                                                                              
##### 
###chkconfig###                                                                                                                                                                                                    
/sbin/chkconfig --add checkflashboot                                                                                                                                                                               
#####       

# Change samba groupe to WORKGROUP
# sed -i 's/MDVGROUP/WORKGROUP/' /etc/samba/smb.conf

#
# DKMS
#

echo
echo
echo Rebuilding DKMS drivers
echo
echo

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

#build arch import for vboxadditions dkms + flash workaround###

export BUILD_TARGET_ARCH=x86
XXX=`file /bin/rpm |grep -c x86-64`
if [ "$XXX" = "1" ];  then
export BUILD_TARGET_ARCH=amd64
fi

echo " ###DKMS BUILD### "
kernel_ver=`ls /boot | /bin/grep vmlinuz | /bin/sed 's/vmlinuz-//' |head -1`
for module in vboxadditions; do
module_version=`rpm --qf '%{VERSION}\n' -q dkms-$module`
module_release=`rpm --qf '%{RELEASE}\n' -q dkms-$module`
su --session-command="/usr/sbin/dkms -k $kernel_ver -a x86_64 --rpm_safe_upgrade add -m $module -v $module_version-$module_release" root
su --session-command="/usr/sbin/dkms -k $kernel_ver -a x86_64 --rpm_safe_upgrade build -m $module -v $module_version-$module_release" root
su --session-command="/usr/sbin/dkms -k $kernel_ver -a x86_64 --rpm_safe_upgrade install -m $module -v $module_version-$module_release --force" root
done

echo "END OF IT".

#/bin/bash
#
# kernel
#

#
# Sysfs must be mounted for dracut to work!
#
mount -t sysfs /sys /sys
ln -s /usr/share/plymouth/themes/Mandriva-Rosa/rosa.png /usr/share/plymouth/themes/Mandriva-Rosa/welcome.png
pushd /lib/modules/
KERNEL=$(echo *)
popd
echo
echo Generating kernel. System kernel is `uname -r`, installed kernels are:
rpm -qa kernel-*
echo Detected kernel version: $KERNEL
echo TEXT THEME

/usr/sbin/plymouth-set-default-theme text
/usr/sbin/dracut --add-drivers "isofs iso9660" /boot/initramfs-$KERNEL.img $KERNEL -v --force
mkdir -p /run/initramfs/live/isolinux/
ln -s /boot/initramfs-$KERNEL.img /run/initramfs/live/isolinux/initrd0.img
#cp -f /boot/initramfs-$KERNEL.img /run/initramfs/live/isolinux/initrd0.img
#ls -l /boot/

echo #######PLYMOUTH#######
/usr/sbin/plymouth-set-default-theme text -R
echo ####PLYMOUTH IS DONE#####

#hack for nscd loop error
while (ps -e | grep nscd)
do
  killall -s 9 nscd
done

echo ""
echo "###################################### Build ISO >> "
echo ""
%end

%post --nochroot
#hack to try to stop umount probs
while (.///lsof /dev/loop* | grep -v "$0" | grep "$INSTALL_ROOT")
do
 sleep 5s
done

   cp -rfT 	.///extraconfig/etc $INSTALL_ROOT/etc/
    cp -rfT 	.///extraconfig/usr $INSTALL_ROOT/usr/
    cp -rfT 	.///extraconfig/var $INSTALL_ROOT/var/
    cp -rfT 	.///extraconfig/var $INSTALL_ROOT/root/
    cp -rfT     .///extraconfig/etc/skel $INSTALL_ROOT/home/live/
    chown -R 500:500 $INSTALL_ROOT/home/live/
    chmod -R 0777 $INSTALL_ROOT/home/live/.local
    chmod -R 0777 $INSTALL_ROOT/home/live/.kde4
    cp -rfT     .///welcome.jpg $INSTALL_ROOT/splash.jpg
    cp -rfT     .///welcome.jpg $INSTALL_ROOT/welcome.jpg
    cp -rfT     .///welcome.jpg $INSTALL_ROOT/splash.jpg
#    mkdir -p $INSTALL_ROOT/var/run/serverinstall
#    cp .///extraconfig/squashfsx86_64.img $INSTALL_ROOT/var/run/serverinstall/squashfs.img

#workaround for flash-plugin
cp -rfT /etc/resolv.conf $INSTALL_ROOT/etc/resolv.conf
/usr/sbin/urpmi.removemedia -a
/usr/sbin/urpmi.addmedia --distrib  --all-media http://abf.rosalinux.ru/downloads/rosa2012.1/repository/x86_64/
/usr/sbin/urpmi --root $INSTALL_ROOT flash-player-plugin
echo > $INSTALL_ROOT/etc/resolv.conf

#end of it
	#delete icon cache
#    rm -f $INSTALL_ROOT/usr/share/icons/gnome/icon-theme.cache
#   rm -f $INSTALL_ROOT/usr/share/icons/nuoveXT2/icon-theme.cache
#    rm -f $INSTALL_ROOT/home/live/.face.icon

#ssh key don't need
    rm -f $INSTALL_ROOT/etc/ssh/*key*

    cp -rfT     .///.counter $INSTALL_ROOT/etc/isonumber
    mkdir -p $LIVE_ROOT/isolinux/
    cp .///extraconfig/memdisk $LIVE_ROOT/isolinux/
    cp .///extraconfig/sgb.iso $LIVE_ROOT/isolinux/

    cp -f 		.///root/GPL $LIVE_ROOT/
#    mkdir -p 	$LIVE_ROOT/Addons
#    cp 	  		/usr/bin/livecd-iso-to-disk			$LIVE_ROOT/Addons/
#    chmod +x 	$LIVE_ROOT/Addons/livecd-iso-to-disk
    rpm --root $INSTALL_ROOT -qa | sort > $LIVE_ROOT/rpm.lst
    ./total_sum_counter.pl -r 640 -h 10 -w $INSTALL_ROOT/ -o $INSTALL_ROOT/etc/minsysreqs
%end