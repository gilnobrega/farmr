# ChiaBot

A discord bot that monitors your chia farm summary and sends notifications when blocks are found and new plots are completed.
The ChiaBot client is available for Linux and Windows. You can interact with the bot in [ChiaBot playground](https://discord.gg/fPjnWYYFmp) discord server.

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

### Troubleshooting
If the client crashes:
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
##### Does your user have permission to access the folders where plots are stored?

##### What if I have two farmers?
  Run one of them as a farmer and the other as a harvester.
## Donate
