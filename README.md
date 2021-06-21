# farmr

A web dashboard that allows you to monitor your Chia farm and sends notifications when blocks are found and new plots are completed through a discord bot. It can link multiple farmers/harvesters to your account.

![image](https://user-images.githubusercontent.com/82336674/121625370-41d93f00-ca6b-11eb-9152-03cabc89a1b6.png)

The farmr client collects local stats about your farm and it is available for Windows, Linux and macOS [here](https://github.com/joaquimguimaraes/farmr/releases/latest). 
The dashboard can be found in [farmr.net](https://farmr.net). Alternatively, you can interact with the bot in [Swar's Chia Community](https://discord.gg/q5T4QbwcnH) discord server. You must be in this server to receive notifications.

## Table of Contents
- [Installation](#Installation)
  - [Updating](#Updating)
- [Commands](./docs/commands.md)
- [Usage](./docs/usage.md#Usage)
  - [Pools](./docs/usage.md#Pools)
    - [FoxyPool](./docs/usage.md#FoxyPool%20(chia-og)%20Mode)
    - [HPool](./docs/usage.md#HPool%20Mode)
  - [Configuration](./docs/configuration.md#Configuration)
    - [Forks](./docs/configuration.md#Forks)
    - [Options](./docs/configuration.md#Options)
- [FAQ](#FAQ)
- [Donate](#Donate)
- [Developer Compiling](./docs/development.md)

## Installation 
Proceed with the following platform-specific instructions:

### Windows
1. Download ``farmr-windows-amd64.zip`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.

- If you're setting up a **farmer/full-node** (need to have at least 1 farmer/full-node linked to your account)
   1. Open ``farmer.exe``, once you see the main screen with your id and farmer stats you're good to go.
   2. Link your device to your discord account as shown in [First Time](#first-time)

- If you're setting up a **harvester**
   1. Open ``harvester.exe``, once you see the main screen with your id and harvester stats you're good to go.
   2. Link your device to your discord account as shown in [First Time](#first-time)

Do not run both ``farmer.exe`` and ``harvester.exe`` in the same PC at the same time!


### Ubuntu (16.04+), and other amd64 Linux distros
1. Download ``farmr-linux-amd64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)

If you're on ubuntu and can't open ``farmer.sh`` or ``harvester.sh`` from file explorer you can run this command:
```
gsettings set org.gnome.nautilus.preferences executable-text-activation ask
```
Then reopen file explorer in the folder where ``farmr-linux-amd64.tar.gz`` was extracted to. You should be able to double click ``farmer.sh`` or ``harvester.sh`` and let it "Run in terminal" when asked to.


### Ubuntu for Raspberry Pi and other arm64/aarch64 Linux distros
1. Download ``farmr-linux-aarch64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)


### macOS (use Rosetta for m1 devices)
1. Download ``farmr-macos-amd64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](#first-time)

#### Updating
To update, repeat [Installation](#installation) instructions again with the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest).
If you wish to keep its settings, move ``config.json`` from the previous installation folder to the new folder.
Similarly, you may keep the previous cache file by doing the same with ``.farmr_cache.json``. This file is hidden in Linux/macOS.

---
## First time
The farmr client will generate an id for your device. 
After you've logged in to [farmr.net](https://farmr.net), you can link this device by clicking on "Add device" in the upper right corner of the dashboard, where you can copy and paste the random id (e.g.: ``e134104c-0e2e-49e0-a832-985c5a5e4516``) and then click "Add".

![tutorial](https://user-images.githubusercontent.com/82336674/121625132-c4adca00-ca6a-11eb-8906-c3d90bbf85c0.gif)

Alternatively, you can link this device to your discord account by heading to [Swar's Chia Community](https://discord.gg/q5T4QbwcnH) and sending the following message:
```
!chia link [your-client-id]
```
The client will save your id in its cache file (``.farmr_cache.json``), so you only need to run this command once per device. Mind you that you will need to do this again if this file gets deleted/corrupt.

### Troubleshooting

##### My farmer/harvester doesn't have plots. Can I still use farmr?
Yes, your client will add itself when chia completes a plot.

If the client crashes:
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
  If they're not, then mount them.
##### Does your user have permission to access the folders where plots are stored?
  farmr will not be able to list your plots if their folder was mounted as root.

##### What if I have two or more farmers?
  Run one of them as a farmer and the others as harvesters.
 
##### Help, I linked the same device twice and it's showing two devices.
  Inactive clients will expire after 15 minutes.
  
## FAQ

##### Are you going to steal my keys?
No. The only commands issued by farmr client is ``chia farm summary`` for farmer stats, ``chia wallet show`` for wallet balance parsing and ``chia show -c`` to count how many peers are connected to your full node. It does not use Chia's RCP servers, therefore it doesn't even need your private key.

##### How can I trust you?
This project is open-source, so you don't have to trust me. Read the code yourself :)
Besides, every binary is built by a github action and signed with a GPG key.

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
LTC: LWPkaD4P7bKpU28RTV4sP41jnrQ3NMDs5y
ADA: addr1q8uw5jh3q0eujj6gqngrdgvr7r6gvqj5qv6tsp77d6usgcv6jehyxjelvffwv53r0avad874vk6snsq3tmmj7z27w73s9kxdkv
USDC (ERC20/BEP20): 0x340281cbad30702af6dca467e4f2524916bb9d61
USDT (ERC20/BEP20): 0x340281cbad30702af6dca467e4f2524916bb9d61
USDT (TRC20): TFddaDuxHUFvtuhLtwodQmNB4ZjJRc4P8k
BNB: 0x340281cbad30702af6dca467e4f2524916bb9d61
BTC: 1Gdzsx6VjZrDxP43y1pgkNMZGsyL357odS
BTC (BEP20): 0x340281cbad30702af6dca467e4f2524916bb9d61
```


## Acknowledgements
Dashboard's structure based on the work by Abu Anwar MD Abdullah [@abuanwar072/Flutter-Responsive-Admin-Panel-or-Dashboard](https://github.com/abuanwar072/Flutter-Responsive-Admin-Panel-or-Dashboard), licensed under MIT license.

[Poppins font](https://fonts.google.com/specimen/Poppins#standard-styles) designed by Indian Type Foundry, Jonny Pinhorn, licensed under Open Font License.

Icons by Google and [Material Design Icons](https://materialdesignicons.com/)


This project is not affiliated with [Chia Network™](https://www.chia.net/).
