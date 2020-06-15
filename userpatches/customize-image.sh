#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	SetupRootUser
	SetupExternalRepos

	display_alert "Use common wlanX name for interfaces" "" "info"
	sudo ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

	SetDefaultShell
	AddUserWLANPi
	SetupRNDIS
	SetupOtherConfigFiles
	SetupPipxEnviro
	InstallPipx
	# InstallSpeedTest
	InstallSpeedTestPipx
	# InstallProfiler
	InstallProfilerPipx
	SetupCockpit
	SetupWebGUI
	SetupOtherServices

} # Main

# This sets up all external debian repos so we can call "apt update" only once here
SetupExternalRepos() {
	###### speedtest ######
	#export INSTALL_KEY=379CE192D401AB61
	# Debian versions supported: jessie, stretch, buster
	#export DEB_DISTRO=$(lsb_release -sc)
	#sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
	#echo "deb https://ookla.bintray.com/debian ${DEB_DISTRO} main" | sudo tee /etc/apt/sources.list.d/speedtest.list
	###### speedtest ######

	#apt update
	display_alert "No external repo currently used" "" "info"
}

SetupPipxEnviro() {
	mkdir -p /opt/wlanpi/pipx/bin
	chown -R root:sudo /opt/wlanpi/pipx
	chmod -R g+rwx /opt/wlanpi/pipx
	cat <<EOF >> /etc/environment
PIPX_HOME=/opt/wlanpi/pipx
PIPX_BIN_DIR=/opt/wlanpi/pipx/bin
EOF
}

InstallPipx() {
	python3 -m pip install pipx
}

InstallSpeedTest() {
	display_alert "Install speedtest-cli" "" "info"

	# Repo was included on SetupExternalRepos
	#apt -y --allow-unauthenticated install speedtest

	# Install unofficial speedtest-cli from pip
	python3 -m pip install speedtest-cli
}

InstallSpeedTestPipx() {
	# Install unofficial speedtest-cli from pip via pipx
	pipx install --include-deps speedtest-cli
}

InstallProfiler() {
	display_alert "Install profiler2" "" "info"

	git clone https://github.com/joshschmelzle/profiler2.git
	cd profiler2

	# install with pip (recommended)
	python3 -m pip install .

	cd ..
	rm -rf profiler2

	install -o root -g root -m 644 /tmp/overlay/lib/systemd/system/profiler.service /lib/systemd/system
}

InstallProfilerPipx() {
	# install with pip via pipx
	pipx install git+https://github.com/joshschmelzle/profiler2.git@0.0.1.dev6#egg=profiler2
	install -o root -g root -m 644 /tmp/overlay/lib/systemd/system/profiler.service /lib/systemd/system
}

SetupCockpit() {
	display_alert "Setup cockpit" "" "info"

	# Enable service
	systemctl enable cockpit.socket
}

SetDefaultShell() {
	# Change default shell to bash
	SHELL_BASH=$(which bash)
	display_alert "Setting default bash" "$SHELL_BASH" "info"

	sed -i "s|^SHELL=.*$|SHELL=${SHELL_BASH}|" /etc/default/useradd
}

SetupRNDIS() {
	display_alert "Setup RNDIS" "" "info"

	echo "options g_ether host_addr=5e:a4:f0:3e:31:d3 use_eem=0" > /etc/modprobe.d/g_ether.conf

	cat <<-EOF >> /etc/network/interfaces

# USB Ethernet
allow-hotplug usb0
iface usb0 inet static
address 169.254.42.1
netmask 255.255.255.224
EOF

	cat <<-EOF > /etc/default/isc-dhcp-server
DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
DHCPDv4_PID=/var/run/dhcpd.pid
INTERFACESv4="usb0"
EOF

	cat <<-EOF >> /etc/dhcp/dhcpd.conf

# usb0 DHCP scope
subnet 169.254.42.0 netmask 255.255.255.224 {
	interface usb0;
	range 169.254.42.2 169.254.42.30;
	option domain-name-servers wlanpi.local;
	option domain-name "wlanpi.local";
	option routers 169.254.42.1;
	option broadcast-address 169.254.42.31;
	default-lease-time 600;
	max-lease-time 7200;
}
EOF
}

SetupRootUser() {
	display_alert "Setup root user options" "" "info"
	rm -f /root/.not_logged_in_yet

	display_alert "Set root password" "" "info"
	echo "root:Wlanpi!" | chpasswd

	display_alert "Copy script to enable/disable root on demand to facilitate developement" "" "info"
	install -o root -g root -m 744 /tmp/overlay/usr/bin/enableroot /usr/bin

	display_alert "Disable root login" "" "info"
	enableroot 0
}

AddUserWLANPi() {
	display_alert "Adding WLAN Pi user" "" "info"
	useradd -m wlanpi
	echo wlanpi:wlanpi | chpasswd
	usermod -aG sudo wlanpi

	display_alert "Include system binaries in wlanpi's PATH - avoid using sudo" "" "info"
	echo 'export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"' >> /home/wlanpi/.profile
}

SetupWebGUI() {
	display_alert "Setup WebGUI" "" "info"

	git clone https://github.com/WLAN-Pi/wfe_v2.git
	cp -ra wfe_v2/site/* /var/www/html
	rm -rf wfe_v2

	chown -R www-data:www-data /var/www/html
}

InstallWLANPiApps() {
	display_alert "Install pkg_admin modules" "" "info"
	for app in $(/usr/local/sbin/pkg_admin -c 2>/dev/null | sed -n '/---/,/---/p' | grep -v -- '---' | grep -v 'Installer script started' | grep -v -e '^$')
	do
		display_alert "Install" "$app" "info"
		/usr/local/sbin/pkg_admin -i $app
	done
}

SetupOtherServices() {
	display_alert "Setup service" "iperf3" "info"
	install -o root -g root -m 644 /tmp/overlay/lib/systemd/system/iperf3.service /lib/systemd/system
	systemctl enable iperf3

	display_alert "Setup service" "iperf2" "info"
	install -o root -g root -m 644 /tmp/overlay/lib/systemd/system/iperf2.service /lib/systemd/system
}

SetupOtherConfigFiles() {
	display_alert "Set retry for dhclient" "" "info"
	if grep -q -E "^#?retry " /etc/dhcp/dhclient.conf; then
		sed -i 's/^#\?retry .*/retry 15;/' /etc/dhcp/dhclient.conf
	else
		echo "retry 15;" >> /etc/dhcp/dhclient.conf
	fi

	display_alert "Set default DNS nameserver on resolveconf template" "" "info"
	echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/tail

	display_alert "Add our custom sudoers file" "" "info"
	install -o root -g root -m 440 /tmp/overlay/etc/sudoers.d/wlanpidump /etc/sudoers.d

	display_alert "Copy ufw rules" "" "info"
	install -o root -g root -m 640 /tmp/overlay/etc/ufw/user.rules /etc/ufw

	display_alert "Enable UFW on first boot script" "" "info"
	sed -i '/start)/a ufw enable' /usr/lib/armbian/armbian-firstrun

	display_alert "Include wlanpi release file" "" "info"
	install -o root -g root -m 644 /tmp/overlay/etc/wlanpi-release /etc/wlanpi-release

	display_alert "Setup" "TFTP" "info"
	usermod -a -G tftp wlanpi
	chown -R root:tftp /srv/tftp
	chmod 775 /srv/tftp

	display_alert "Generate locale" "en_US.UTF-8" "info"
	locale-gen --purge en_US.UTF-8
}

InstallMongoDB() {
	file_name="mongodb-src-r4.2.6"
	prev_pwd=$PWD
	cd /root/build

	display_alert "Download mongo" "" "info"
	wget -nc https://fastdl.mongodb.org/src/$file_name.tar.gz

	display_alert "Unpack mongo" "" "info"
	tar -zxvf $file_name.tar.gz
	cd $file_name

	display_alert "Install requirements" "" "info"
	python3 -m pip install wheel
	python3 -m pip install -r buildscripts/requirements.txt

	display_alert "Build mongo" "" "info"
	python3 buildscripts/scons.py core --ssl CCFLAGS=-march=armv8-a+crc

	display_alert "Clean up build objects" "" "info"
	cd ..
	rm -rf $file_name
	cd $prev_pwd
}

#########
# Let's have unique way of displaying alerts
# Copied from Armbian build to standardize prints
#########
display_alert()
{
	# log function parameters to install.log
	[[ -n $DEST ]] && echo "Displaying message: $@" >> $DEST/debug/output.log

	local tmp=""
	[[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

	case $3 in
		err)
		echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
		;;

		wrn)
		echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
		;;

		ext)
		echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
		;;

		info)
		echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
		;;

		*)
		echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
		;;
	esac
}

Main "$@"
