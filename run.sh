#!/bin/sh

#Installs dart
if [ ! -f "/usr/bin/dart" ]; then

    echo "Installing dependencies (dart, git, screen)";
    sleep 2 ;
    wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/linux_packages/dart_2.12.2-1_amd64.deb -O dart.deb;
    sudo dpkg -i dart.deb;
    rm dart.deb;
    sudo apt-get install -f;

fi

#Installs git
if [ ! -f "/usr/bin/git" ]; then
    sudo apt-get install git screen -y;
fi

#Installs screen
if [ ! -f "/usr/bin/screen" ]; then
    sudo apt-get install screen -y;
fi

#Updates repo
git init;
git remote add origin https://github.com/joaquimguimaraes/chiabot.git;
git stash; git pull;

dart pub get;
screen -d -R -S chiabot sh run.sh $1 ;
