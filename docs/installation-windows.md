## Installing farmr on Windows 

### Farmer/Full-node or Harvester
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.7.0/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``farmr.exe``, once you see the main screen with your id and farmer stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor farming other cryptocurrencies such as flax and chaingreen.

### HPool Mode
1. Download [farmr-windows-x64.zip](https://github.com/joaquimguimaraes/farmr/releases/download/v1.7.0/farmr-windows-x64.zip) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open ``hpool.exe``, it will generate a template ``config-xch.json`` file in ``config`` directory and then it will show an error. This is expected since ``"HPool Directory"`` has not been set.
3. Edit ``config-xch.json`` in ``config`` folder and set ``"HPool Directory"`` to the path where HPool is installed (there should be a file named ``config.yaml`` in this path).
4. Open ``hpool.exe`` again. Once you see the main screen with your id and stats you're good to go.
5. Link device to your discord account as shown in [First Time](./usage.md#First-time)

Read [Configuration](configuration.md#showing-hpool-balance) if you want it to show total balance, settled and unsettled balance from HPool's website.

