#!/bin/bash

echo "packer: updating aptitude"
sudo apt-key update
sudo apt-get update
sudo apt-get remove apt-listchanges -y
sudo apt-get install git make g++ graphicsmagick curl python-software-properties software-properties-common -y

echo "packer: creating swap space"
sudo mkdir -p /media/fasthdd
sudo dd if=/dev/zero of=/media/fasthdd/swapfile.img bs=1024 count=3M
sudo mkswap /media/fasthdd/swapfile.img
sudo chmod 0600 /media/fasthdd/swapfile.img
echo "/media/fasthdd/swapfile.img swap swap sw 0 0" | sudo tee -a /etc/fstab
sudo swapon /media/fasthdd/swapfile.img

echo "packer: nvm"
curl https://raw.githubusercontent.com/creationix/nvm/$NVM_VERSION/install.sh | bash
. $HOME/.nvm/nvm.sh

echo '[[ -s $HOME/.nvm/nvm.sh ]] && . $HOME/.nvm/nvm.sh' >> $HOME/.bashrc

echo "packer: nodejs"
nvm install $NODE_VERSION
nvm alias default $NODE_VERSION
npm update -g npm

echo "packer: precaching server dependencies"
mkdir -p $HOME/app/precache
cp -r /tmp/mailtube $HOME/app/mailtube
cp $HOME/app/mailtube/package.json $HOME/app/precache
npm install --prefix $HOME/app/precache
