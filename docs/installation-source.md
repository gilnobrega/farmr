# Compile from source (every platform/architecture)
1. Download ``source.tar.gz`` or ``source.zip`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to a folder.
2. Download and install [dart sdk](https://dart.dev/get-dart)
3. Open the terminal in the folder you just extracted and run:
```
dart pub get; 
dart run environment_config:generate;
dart compile exe farmr.dart; 
mv farmr.exe farmr;
```
4. Run ``./farmr`` once you see the main screen with your id and farmer/harvester stats you're good to go.
5. Link your device to your discord account as shown in [First Time](./usage.md#First-time)

Note: Local Cold Wallets will only work if SQLite 3 is installed in your device.
To install it in ubuntu or debian, run the command
```sudo apt-get install libsqlite3-dev```