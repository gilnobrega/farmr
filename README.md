# ChiaBot

A discord bot that monitors your chia farm summary and sends notifications when blocks are found and new plots are completed.
Client is available for Linux and Windows.

## Installation 
Download this repository, then proceed with the following platform-specific instructions:

### Windows
1. Open `` install.bat `` as an **administrator**
2. Now as a regular user, open `` run.bat `` if you're setting up your farmer (main machine) or `` run_harvester.bat `` if it's a harvester.

### Ubuntu (16.04+), Debian and other Debian-based distros
1. Open terminal in project's root directory and then run `` sh run.sh `` if you're setting up your farmer (main machine) or `` sh run_harvester.sh `` if it's a harvester.
The script will install dart, git and screen and setup the client for you.

### Raspberry Pi (with a 64-bit OS)

### Other Linux distros
## Usage

### Troubleshooting
If the client crashes:
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
##### Does your user have permission to access the folders where plots are stored?

##### What if I have two farmers?
  Run one of them as a farmer and the other as a harvester.
## Donate
