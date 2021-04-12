#!/bin/sh
if [ ! -f "/usr/bin/dart" || ! -f "/usr/bin/screen" || ! -f "/usr/bin/git"]; then

    echo "Installing dependencies (dart, git, screen)";
    sleep 2 ;
    wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/linux_packages/dart_2.12.2-1_amd64.deb -O dart.deb;
    sudo dpkg -i dart.deb;
    sudo apt-get install git screen -y;
    sudo apt-get install -f;
    rm dart.deb;

    git init;
    git remote add origin https://github.com/joaquimguimaraes/chiabot.git;

    dart pub get;
fi

git stash; git pull;
dart pub get;
screen -d -R -S chiabot sh run.sh $1 ;
