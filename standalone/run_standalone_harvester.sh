#!/bin/sh

#Detects architecture https://stackoverflow.com/questions/48678152/how-to-detect-386-amd64-arm-or-arm64-os-architecture-via-shell-bash
architecture=""
case $(uname -m) in
    i386)   architecture="386" ;;
    i686)   architecture="386" ;;
    x86_64) architecture="amd64" ;;
    arm)    dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
    aarch64) architecture="arm64";
esac

echo $architecture;

if [ "$architecture" = "amd64" ]; then

    dartpath="/usr/bin/dart";

    #Installs dart
    if [ ! -f "$dartpath" ]; then

        echo "Installing dependencies (dart, git, screen)";
        sleep 2 ;
        wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/linux_packages/dart_2.12.4-1_amd64.deb -O dart.deb;
        sudo dpkg -i dart.deb;
        rm dart.deb;
        sudo apt-get install -f;
    fi

fi

#Raspberry pi installation script
if [ "$architecture" = "arm64" ]; then

    dartpath="dart-sdk/bin/dart";

    #Installs dart - path will be dart-sdk/bin/dart
    if [ ! -f "$dartpath" ]; then

        echo "Installing dependencies (dart, git, screen)";
        sleep 2 ;
        sudo apt-get install unzip;
        wget https://storage.googleapis.com/dart-archive/channels/stable/release/2.12.2/sdk/dartsdk-linux-arm64-release.zip -O dart.zip;
        unzip dart.zip;
    fi

fi

#Installs git
if [ ! -f "/usr/bin/git" ]; then
    sudo apt-get install git screen -y;
fi

#Installs screen
if [ ! -f "/usr/bin/screen" ]; then
    sudo apt-get install screen -y;
fi

$dartpath pub get;
screen -q -d -R -S farmr $dartpath ../farmr.dart standalone harvester;
