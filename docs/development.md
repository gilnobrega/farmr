# Compile from source (every platform/architecture)
1. Download ``source.tar.gz`` or ``source.zip`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to a folder.
2. Download and install [dart sdk](https://dart.dev/get-dart)
3. Open the terminal in the folder you just extracted and run:
   - If you're setting up a **farmer**:
```
dart pub get; 
dart run environment_config:generate;
dart compile exe farmr.dart; 
mv farmr.exe farmr;
```
   - If you're setting up a **harvester**:
```
dart pub get; 
dart run environment_config:generate;
dart compile exe farmr_harvester.dart; 
mv farmr_harvester.exe farmr;
```
4. Run ``./farmr`` once you see the main screen with your id and farmer/harvester stats you're good to go.
5. Link your device to your discord account as shown in [First Time](#first-time)