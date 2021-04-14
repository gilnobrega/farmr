# ChiaBot

A discord bot that monitors your chia farm summary and sends notifications when blocks are found and new plots are completed.
The ChiaBot client is available for Linux and Windows. You can interact with the bot in [ChiaBot playground](https://discord.gg/fPjnWYYFmp) discord server.

![screenshot](https://i.imgur.com/EJElMdH_d.webp?maxwidth=400&fidelity=grand)

![notifications](https://i.imgur.com/ZxVmS0L_d.webp?maxwidth=400&fidelity=grand)

## Installation 
Download this repository, then proceed with the following platform-specific instructions:

#### Windows
1. Open `` install.bat `` as an **administrator**
2. Now as a regular user, open 
   - `` run.bat `` if you're setting up your farmer (main machine) 
   - `` run_harvester.bat `` if it's a harvester.

#### Ubuntu (16.04+), Debian and other Debian-based distros
1. Open terminal in project's root directory and then run 
   - `` sh run.sh `` if you're setting up your farmer (main machine) 
   - ``sh run_harvester.sh `` if it's a harvester.
The script will install dart, git, screen and setup the client for you.

#### Raspberry Pi and other devices (running amd64/arm64 Linux)
1. Install dart, git and screen using your distro's package manager
2. Run 
   - `` sh run.sh `` if you're setting up your farmer (main machine)
   - `` sh run_harvester.sh `` if it's a harvester.
If you have trouble running the script try running `` dart pub get`` and `` dart chiabot.dart `` manually.

### First time
ChiaBot will generate an id for your device. You can link this device to your discord account by heading to [ChiaBot playground](https://discord.gg/fPjnWYYFmp) and sending the following message:
```
!chia link [your-client-id]
```
ChiaBot will save your id, so you only need to do this once per device.

### Upgrading
To upgrade, download this repository again and replace the previous files. 
If you're on Windows, there's no need to run `` install.bat ``.
Your device will keep its id so you don't have to link it another time.

## Usage
If your device was linked sucessfully, you may use `` !chia `` to see your farm summary, or `` !chia full `` to display some statistics about it.
To see the full list of commands you can use, type: `` !chia help ``

Please note that on Windows, you **must not close** ``run.bat`` as that will kill the client. If you do so, open it again.

On Linux it is safe to close ``run.sh``, as it runs it in background and reopening will reattach to the client's process.
Press ``ctrl+c`` when you want to close the client. You must reopen ``run.sh`` after restarting your computer.

### Extra configuration
ChiaBot stores your config in ``~/.chia/mainnet/config/chiabot.json``
This is how it looks like:
```json
[{
"id":"ea0186b0-1524-42a9-9e1e-3c4196a15b8b",
"type":0,
"binPath":"/lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia",
"showBalance":true,
"sendPlotNotifications":true,
"sendBalanceNotifications":true
}]
```
``"type": 0`` means your client was initialized as a farmer, while ``"type": 1`` is for harvesters. You can change these values if you wish to convert your farmer into a harvester or otherwise.
You may set ``sendPlotNotifications`` and ``sendBalanceNotifications`` to ``false`` if you do not wish to receive notifications.
You may delete this file to reset settings and generate a new id.

### Troubleshooting
If the client crashes:
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
  If they're not, then mount them.
##### Does your user have permission to access the folders where plots are stored?
  ChiaBot will not be able to list your plots if their folder was mounted as root.


##### What if I have two farmers?
  Run one of them as a farmer and the other as a harvester.
  
## Donate
@joaquimguimaraes wallet addresses:
```
XCH: xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9
ETH: 0x340281CbAd30702aF6dCA467e4f2524916bb9D61
```
