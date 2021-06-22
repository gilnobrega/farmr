## Installing farmr on Windows 

### Farmer/Full-node
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.4.1.3/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``farmer.exe``, once you see the main screen with your id and farmer stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor farming other cryptocurrencies such as flax and chaingreen.

### Harvester
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.4.1.3/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``harvester.exe``, once you see the main screen with your id and harvester stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor harvesting other cryptocurrencies such as flax and chaingreen.

### FoxyPool Mode
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.4.1.3/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``foxypoolog.exe``, once you see the main screen with your id and farmer stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Lean how you can [enable FoxyPool balance](configuration.md#showing-foxypool-balance) or read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

### HPool Mode
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.4.1.3/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``hpool.exe``, it will generate a template ``config-xch.json`` file in ``config`` directory and then it will show an error. This is expected since ``"HPool Directory"`` has not been set.
3. Edit ``config-xch.json`` in ``config`` folder and set ``"HPool Directory"`` to the path where HPool is installed (there should be a file named ``config.yaml`` in this path).
4. Open ``hpool.exe`` again. Once you see the main screen with your id and stats you're good to go.
5. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Read [Configuration](configuration.md#showing-hpool-balance) if you want it to show total balance, settled and unsettled balance from HPool's website.

