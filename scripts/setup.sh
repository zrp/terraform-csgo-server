#!/usr/bin/env bash

# Add multiverse for x64 systems
sudo add-apt-repository multiverse
sudo dpkg --add-architecture i386

# Update and upgrade
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install gnome-session gdm3 tigervnc-standalone-server tigervnc-common firefox htop -y

# Install linux gsm with csgoserver
wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh csgoserver

# Setup crontab
(crontab -l 2>/dev/null; echo "*/5 * * * *   /home/csgoserver/csgoserver monitor > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/30 * * * *  /home/csgoserver/csgoserver update > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "30 4 * * *    /home/csgoserver/csgoserver force-update > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * 0     /home/csgoserver/csgoserver update-lgsm > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "@reboot       /home/csgoserver/csgoserver restart > /dev/null 2>&1") | crontab -

