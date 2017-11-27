#!/bin/bash

echo "packer: installing appserver daemon..."
echo "#!/bin/bash" > $HOME/app/start
echo ". $HOME/.nvm/nvm.sh" >> $HOME/app/start
echo "node $HOME/app/server/server.js" >> $HOME/app/start
chmod +x $HOME/app/start
cp /tmp/mailtube/init.d/appserver.conf $HOME/app/$NAME.conf
sed -i "s#{NAME}#$NAME#g" $HOME/app/$NAME.conf
sed -i "s#{DESCRIPTION}#Web application daemon service for $NAME#g" $HOME/app/$NAME.conf
sed -i "s#{USER}#$INSTANCE_USER#g" $HOME/app/$NAME.conf
sed -i "s#{COMMAND}#$HOME/app/start#g" $HOME/app/$NAME.conf
sudo mv $HOME/app/$NAME.conf /etc/init.d/$NAME
sudo chmod +x /etc/init.d/$NAME
sudo touch /var/log/$NAME.log
sudo chown $INSTANCE_USER /var/log/$NAME.log
sudo update-rc.d $NAME defaults

echo "packer: sourcing nvm"
. $HOME/.nvm/nvm.sh

echo "packer: moving uploaded server code"
mv /tmp/app $HOME/app/server

echo "packer: installing server dependencies"
npm install --prefix $HOME/app/server

echo "packer: booting appserver daemon..."
sudo service $NAME start
