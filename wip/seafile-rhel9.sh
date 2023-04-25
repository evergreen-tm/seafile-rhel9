#!/bin/bash

###
### install Seafile on Rocky Linux 9 via docker compose
### version: 0.1
###

set -e

setup() {
	printf "\n DISCLAIMER: This script is meant to be ran on a fresh install, and may not work properly if it is not ran on such. I am not responsible for anything that happens. \n "
	printf "You should also have a partition already setup to use for Seafile data\n\n" && sleep 10

	echo "Installing and configuring Docker..." && sleep 1
	sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	sudo dnf install -y docker-ce docker-ce-cli containerd.io
	sudo systemctl enable --now docker 
	sudo usermod -aG docker $(whoami)
    sudo gpasswd -r docker
	newgrp docker

	printf "\nSetting up Seafile...\n"
	sudo mkdir -p /srv/www/seafile && sudo chown -R $(whoami) /srv/www/seafile
	cd /srv/www/seafile && curl -fLO https://raw.githubusercontent.com/fishe-tm/seafile-rhel9/main/docker-compose.yml
	docker compose up -d
	printf "\nGiving Seafile a 'settle time' of 20sec before shutting down again (issues with mysql pop up if this is not done)\n" && sleep 20
	docker compose down

	clear; lsblk && sudo blkid
	printf "\n\nPlease copy the UUID of the drive partition you'd like to use for Seafile data and paste it here, without quotes and without the 'UUID='\n"
	read -p "Enter here: " uuid
	printf "\nNice! Now pick a place for the drive to be mounted (something like /mnt/seafile, DO NOT ADD trailing /)\n"
	read -p "Enter here: " drive_loc
	filesystem=$(lsblk -f /dev/disk/by-uuid/$uuid)
	filesystem=${filesystem#*$'\n'}
	filesystem=$(echo "$filesystem" | awk '{print $2}')

	if grep $uuid /etc/fstab; then 
		drive_loc=$(grep "$uuid" /etc/fstab | awk '{print $2}')
		printf "\nPartition of UUID $uuid is already in fstab with mountpoint at $drive_loc; using this instead\n"
	else 
		echo "UUID=$uuid   $drive_loc   $filesystem	  defaults   0 0" | sudo tee -a /etc/fstab
		printf "\nThis partition has been added to fstab and will mount automatically every reboot.\n" && sleep 2
		sudo systemctl daemon-reload
		[ ! -d "$drive_loc" ] && sudo mkdir "$drive_loc"
	fi

	sudo mount -a
 
	sudo mv /opt/seafile-data /opt/seafile-data_bak
	sudo cp -r /opt/seafile-data_bak $drive_loc/seafile-data
	sudo mkdir -p /shared/seafile/seafile-data

	sed -i "s%- /opt/seafile-data:/shared%- $drive_loc/seafile-data:/shared%g" docker-compose.yml
	sed -i "s%Etc/UTC%$(timedatectl show --va -p Timezone)%g" docker-compose.yml
	printf "\nNow let's make an admin user! Enter an email to use for the admin user.\n" && read -p "Enter here: " admin_email
	read -sp "Now a password: " admin_password
	sed -i "s%me@example.com%$admin_email%g" docker-compose.yml
	sed -i "s%asecret%$admin_password%g" docker-compose.yml

	docker compose up -d
}

tailscale() {
	printf "\nInstalling tailscale, be ready to connect it to your tailnet" && sleep 2
	sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo
	sudo dnf install -y tailscale
	sudo systemctl enable --now tailscaled
	sudo tailscale up
}

main() {
	setup

	printf "\nSeafile is now running and can be accessed locally at $(hostname -I | cut -d' ' -f1) on port 80.\n\n"
	read -p "Install and configure Tailscale? (Y/n) " tailscaler
	if [ "${tailscaler,,}" == "y" ]; then tailscale; else echo "Ok, skipped."; fi


	printf "\nDone!\n"
	cat <<- EOF
	Seafile docker-compose.yml file's at:	/srv/www/seafile
	Seafile data partition is mounted at:	$drive_loc
	Original /opt/seafile-data is now at:	/opt/seafile-data_bak
	EOF
}

main
