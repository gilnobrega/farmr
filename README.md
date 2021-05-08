# Joaquim's ChiaBot

A discord bot that monitors your chia farm summary and sends notifications when blocks are found and new plots are completed. It can link multiple farmers/harvesters to your account.

The ChiaBot client is available for Windows, Linux and macOS. You can interact with the bot in [ChiaBot playground](https://discord.gg/aEkYWQGWdS) discord server.

### Main Features
| ``!chia`` command | Block, Plot and Offline notifications |
|-----------------------------------------------------|-------------------|
|![screenshot](https://i.imgur.com/ilPYPe3_d.webp?maxwidth=450&fidelity=grand)|![notifications](https://i.imgur.com/HXKroKS_d.webp?maxwidth=450&fidelity=grand)|

| ``!chia full`` for detailed stats | ``!chia workers`` for client-specific stats |
|------------------------|-------------------|
|![chiafull](https://i.imgur.com/7GEM6Z3_d.webp?maxwidth=450&fidelity=grand)|![chiaworkers](https://i.imgur.com/2AOeYcR_d.webp?maxwidth=450&fidelity=grand)|

| Challenge Parsing | Full Node stats |
|------------------------|-------------------|
|![challenges](https://i.imgur.com/PpmlJj6_d.webp?maxwidth=450&fidelity=grand)|![fullnode](https://i.imgur.com/R1OOemY_d.webp?maxwidth=450&fidelity=grand)|

## Installation 
Proceed with the following platform-specific instructions:

#### Windows
- If you're setting up a **farmer/full-node**
   1. Download ``chiabot-windows-amd64.exe`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and move it to an **empty** folder.
   2. Open ``chiabot-windows-amd64.exe``, once you see the main screen with your id and farmer stats you're good to go.
   3. Link your device to your discord account as shown in [First Time](#first-time)

- If you're setting up a **harvester**
   1. Download ``chiabot_harvester-windows-amd64.exe`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and move it to an **empty** folder.
   2. Open ``chiabot_harvester-windows-amd64.exe``, once you see the main screen with your id and harvester stats you're good to go.
   3. Link your device to your discord account as shown in [First Time](#first-time)

#### Ubuntu (16.04+), and other amd64 Linux distros
1. Download ``chiabot-linux-amd64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)

#### Ubuntu for Raspberry Pi and other arm64 Linux distros
1. Download ``chiabot-linux-arm64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)

#### macOS (m1 not supported)
1. Download ``chiabot-macos-amd64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)

#### Compile from source (every platform/architecture)
1. Download ``source.tar.gz`` or ``source.zip`` from the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest) and extract it to a folder.
2. Download and install [dart sdk](https://dart.dev/get-dart)
3. Open the terminal in the folder you just extracted and run:
   - If you're setting up a **farmer**:
```
dart pub get; 
dart compile exe chiabot.dart; 
mv chiabot.exe chiabot;
```
   - If you're setting up a **harvester**:
```
dart pub get; 
dart compile exe chiabot_harvester.dart; 
mv chiabot_harvester.exe chiabot;
```
4. Run ``./chiabot`` once you see the main screen with your id and farmer/harvester stats you're good to go.
5. Link your device to your discord account as shown in [First Time](#first-time)

### First time
ChiaBot will generate an id for your device. You can link this device to your discord account by heading to [ChiaBot playground](https://discord.gg/aEkYWQGWdS) and sending the following message:
```
!chia link [your-client-id]
```
ChiaBot will save your id in its cache file (``.chiabot_cache.json``), so you only need to run this command once per device.

### Upgrading
To upgrade, repeat [Installation](#installation) instructions again with the [latest release](https://github.com/joaquimguimaraes/chiabot/releases/latest).
If you wish to keep its settings, move ``config.json`` from the previous installation folder to the new folder.
Similarly, you may keep the previous cache file by doing the same with ``.chiabot_cache.json``. This file is hidden in Linux/macOS.

## Usage
If your device was linked sucessfully, you may use `` !chia `` to see your farm summary, or `` !chia full `` to display additional statistics about it and `` !chia workers `` to show them per farmer/harvester.
To see the full list of commands you can use, type: `` !chia help ``

Please note that on Windows, you **must not close** ``run.bat`` or ``run_harvester.bat`` as doing that will kill the client. If you do so, open it again.

On Linux it is safe to close ``run.sh``, as it runs it in background and reopening will reattach to the client's process.
Press ``ctrl+c`` when you want to close the client. You must reopen ``run.sh`` after restarting your computer.

### Configuration
ChiaBot stores your current configuration in ``config.json``
You do not need to edit this file, as it's automatically generated by ChiaBot. However, you may wish to customize some of its options.
If you wish to do so, you can rename ``config.json.default`` to ``config.json`` to change them.
These are the default settings:
```json
[
    {
        "name": null,
        "showBalance": true,
        "sendBalanceNotifications": true,
        "sendPlotNotifications": false,
        "sendOfflineNotifications": false,
        "parseLogs": false,
        "chiaPath": null
    }
]
```

#### Name your client
You can name your client by changing `` "name": null,`` to ``"name": "YourFarmer",`` (notice **quote marks**). This will identify the client as ``YourFarmer`` in `` !chia workers ``.

#### Sharing XCH Balance
Set ``showBalance`` to ``false`` if you do not want your balance to be reported to the server. Setting this to false will disable Block notifications.

#### Plot Notifications
Set ``sendPlotNotifications`` to ``true`` if you wish to be notified when your farmer/harvester completes a plot.

#### Block Notifications
Set ``sendBalanceNotifications`` to ``false`` if you do not wish to be notified when your farmer finds a block.

#### Offline Notifications
Set ``sendOfflineNotifications`` to ``true`` if you wish to be notified when your farmer/harvester loses connection.

#### Status Notifications
Set ``sendStatusNotifications`` to ``true`` if you wish to be notified when your farmer loses sync and stops farming.

#### Chia Log Parsing
If your chia debug level is set to ``INFO`` ([find how to do that here](https://thechiafarmer.com/2021/04/20/how-to-enable-chia-logs-on-windows/)), setting ``parseLogs`` to ``true`` will enable extra stats, such as number of challenges in the last 24 hours, max, min and average challenge response times and incomplete SubSlots.

You may delete ``config.json`` and ``.chiabot_cache.json`` to reset settings and generate a new id once the client is started again.

### Troubleshooting

##### My farmer/harvester doesn't have plots. Can I still use ChiaBot?
Yes, your client will add itself when chia completes a plot.

If the client crashes:
##### Do ``run.bat`` or ``run_harvester.bat`` close suddenly after being opened?
  Try launching CMD as an administrator and opening ``install.bat`` from there. Then do the same with ``run.bat`` or ``run_harvester.bat``.
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
  If they're not, then mount them.
##### Does your user have permission to access the folders where plots are stored?
  ChiaBot will not be able to list your plots if their folder was mounted as root.

##### What if I have two or more farmers?
  Run one of them as a farmer and the others as harvesters.
 
##### Help, I linked the same device twice and it's showing two devices.
  Inactive clients will expire after 15 minutes.
  
## FAQ

##### Are you going to steal my keys?
No. The only command issued by chiabot client is ``chia farm summary``. It does not use Chia's RCP servers, therefore it doesn't even need your private key.

##### How can I trust you?
This project is open-source, so you don't have to trust me. Read the code yourself :)

##### What data is collected?
You can see the data that's currently tied to your discord ID with ``!chia api``
Your wallet address is not sent to the server so your data remains anonymous (that is, except being linked to your discord ID).

##### What if I don't want my data to be stored in your server anymore?
Simple, stop using it. All data will be deleted 15 minutes after your client sent its last report.

## Donate
@joaquimguimaraes wallet addresses:
```
XCH: xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9
ETH: 0x340281CbAd30702aF6dCA467e4f2524916bb9D61
```
