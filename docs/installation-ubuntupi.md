## Installing farmr on Ubuntu for Raspberry Pi
(and other Debian-based distros)

### Farmer/Full-node or Harvester
1. Download [farmr-ubuntu-aarch64.deb](https://github.com/joaquimguimaraes/farmr/releases/latest/download/farmr-ubuntu-aarch64.deb) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
3. Open the terminal and run: ```farmr```, once you see the main screen with your id and farmer stats you're good to go.
4. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor farming other cryptocurrencies such as flax and chaingreen.

### HPool Mode
1. Download [farmr-ubuntu-aarch64.deb](https://github.com/joaquimguimaraes/farmr/releases/latest/download/farmr-ubuntu-aarch64.deb) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
2. Open the terminal and run: ```farmr hpool```, it will generate a template ``config-xch.json`` file in ``config`` directory and then it will show an error. This is expected since ``"HPool Directory"`` has not been set.
3. Edit ``config-xch.json`` in ``~/.farmr/config`` folder and set ``"HPool Directory"`` to the path where HPool is installed (there should be a file named ``config.yaml`` in this path).
4. Run ```farmr hpool``` again. Once you see the main screen with your id and stats you're good to go.
5. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Read [Configuration](configuration.md#showing-hpool-balance) if you want it to show total balance, settled and unsettled balance from HPool's website.

