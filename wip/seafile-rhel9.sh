#!/bin/bash

###
### install Seafile on Rocky Linux 9 via docker compose
###

set -e

first_run() {
    printf "\n DISCLAIMER: This script is meant to be ran on a fresh install, and may not work properly if it is not ran on such. I am not responsible for anything that happens. \n "
    printf "You should also have a partition already setup to use for Seafile data\n\n" && sleep 10

    echo "Installing and configuring Docker..." && sleep 1
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable --now docker 
    sudo usermod -aG docker $(whoami)
    
    mkdir -p ~/.tmp/seafilescript

    printf "\n\n !! System will reboot in 10 seconds for group changes to take effect. !! Terminate (Ctrl + C) to stop this.\n !! Run the script again to continue with configuration !!"
    sleep 10 && sudo reboot
}

second_run() {
    printf "\nSetting up directories and mounts for Seafile...\n"
    printf "\n!! You should have a partition made to use with Seafile !!\n If you do not, exit this script and create it, then run this script again.\n"
    sleep 7 && sudo mkdir -p /srv/www/seafile && sudo chown -R $(whoami) /srv/www/seafile
    cd /srv/www/seafile && curl -fLO https://raw.githubusercontent.com/fishe-tm/seafile-rhel9/main/docker-compose.yml
    clear; lsblk && sudo blkid
    printf "\n\nPlease copy the UUID of the drive partition you'd like to use for Seafile data and paste it here, without quotes\n"
    read -p "Enter here: " uuid
    printf "\nNice! Now pick a place for the drive to be mounted (something like /mnt/seafile, DO NOT ADD trailing /)\n"
    read -p "Enter here: " drive_loc

    filesystem=$(lsblk -f /dev/disk/by-uuid/$uuid)
    filesystem=${filesystem#*$'\n'}
    filesystem=$(echo "$filesystem" | awk  '{print $2}')

    echo "UUID=$uuid $drive_loc $filesystem  defaults  0 0" | sudo tee -a /etc/fstab
    printf "\nThis partition has been added to fstab and will mount automatically every reboot.\n" && sleep 2
    sudo systemctl daemon-reload
    [ ! -d "$drive_loc" ] && sudo mkdir "$drive_loc"
    sudo mount -a
 
    sudo cp -r /opt/seafile-data /opt/seafile-data_bak
    sudo cp -r /opt/seafile-data $drive_loc/
    sudo rm -rf /opt/seafile-data
    sudo mkdir -p /shared/seafile/seafile-data

    sed -i "s%- /opt/seafile-data:/shared%- $drive_loc/seafile-data:/shared%g" /srv/www/seafile/docker-compose.yml
    printf "\nNow let's make an admin user! Enter an email to use for the admin user.\n" && read -p "Enter here: " admin_email
    read -sp "Now a password: " admin_password
    sed -i "s%me@example.com%$admin_email%g" docker-compose.yml
    sed -i "s%asecret%$admin_password%g" docker-compose.yml

    docker compose up -d
    
    ## see if a user can be remotely removed
    #printf "\nYou will now create an admin user. Delete the default one after logging in at System Admin -> Users.\n"
    #docker exec -it seafile /opt/seafile/seafile-server-latest/reset-admin.sh
}

tailscale() {
    printf "\nInstalling tailscale, be ready to connect it to your tailnet" && sleep 2
    sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo
    sudo dnf install -y tailscale
    sudo systemctl enable --now tailscaled
    sudo tailscale up
}

main() {
    if [ -d ~/.tmp ]; then DEL_TMP_DIR="false"; else DEL_TMP_DIR="true" && mkdir ~/.tmp; fi
    if [ ! -d ~/.tmp/seafilescript ]; then FIRSTRUN="true"; else FIRSTRUN="false"; fi
    if [ "$FIRSTRUN" == "true" ]; then first_run; else second_run; fi

    if [ "$DEL_TMP_DIR" == "false" ]; then rm -rf ~/.tmp/seafilescript; else rm -rf ~/.tmp; fi   # using touch doesn't work for some reason, idk man im just a fish

    printf "\nSeafile is now running and can be accessed locally at $(hostname -I | cut -d' ' -f1) on port 80.\n"
    read -p "Install and configure Tailscale? (Y/n)" tailscaler
    if [ "${tailscaler,,}" == "y" ]; then tailscale; else echo "Ok, skipped."; fi

    echo "\nDone!"
    echo "Seafile .yml file is at: /srv/www/seafile"
    echo "Seafile data drive is mounted at: $drive_loc"
    echo "Original out-of-the-box /opt/seafile-data is now at /opt/seafile-data_bak"
}

main
