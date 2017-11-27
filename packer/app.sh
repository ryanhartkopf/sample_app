#!/bin/bash

echo "packer: installing appserver daemon..."
echo "#!/bin/bash" > $HOME/start
echo ". $HOME/.nvm/nvm.sh" >> $HOME/start
echo "node $HOME/app/server/server.js" >> $HOME/start
chmod +x $HOME/start
sed -i "s#{NAME}#$NAME#g" $HOME/appserver.conf
sed -i "s#{DESCRIPTION}#Web application daemon service for $NAME#g" $HOME/appserver.conf
sed -i "s#{USER}#$INSTANCE_USER#g" $HOME/appserver.conf
sed -i "s#{COMMAND}#$HOME/start#g" $HOME/appserver.conf
sudo mv $HOME/appserver.conf /etc/init.d/$NAME
sudo chmod +x /etc/init.d/$NAME
sudo touch /var/log/$NAME.log
sudo chown $INSTANCE_USER /var/log/$NAME.log
sudo update-rc.d $NAME defaults

echo "packer: sourcing nvm"
. $HOME/.nvm/nvm.sh

echo "packer: moving uploaded server code"
mv /tmp/app $HOME/server

echo "packer: installing server dependencies"
npm install --prefix $HOME/server

echo "packer: booting appserver daemon..."
sudo service $NAME start

echo "packer: testing daemon"
curl localhost:8080
ps aux --forest
