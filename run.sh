#!bin/sh
if [ ! -f "/usr/bin/dart" ]; then

    echo "Installing dependencies (dart)";
    sleep 2 ;
    wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/linux_packages/dart_2.12.2-1_amd64.deb -O dart.deb;
    sudo dpkg -i dart.deb;
    sudo apt-get install -f;
    rm dart.deb;

    dart pub get;
fi

dart pub get;
dart chiabot.dart $1 ;
