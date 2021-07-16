## Installing farmr on Fedora

### Farmer/Full-node
1. Download [farmr-fedora-x86_64.rpm](https://github.com/joaquimguimaraes/farmr/releases/download/v1.5.3.2/farmr-fedora-x86_64.rpm) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
3. Open the terminal and run: ```farmr```, once you see the main screen with your id and farmer stats you're good to go.
4. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor farming other cryptocurrencies such as flax and chaingreen.

### Harvester
1. Download [farmr-fedora-x86_64.rpm](https://github.com/joaquimguimaraes/farmr/releases/download/v1.5.3.2/farmr-fedora-x86_64.rpm) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
2. Open the terminal and run: ```farmr harvester```, once you see the main screen with your id and farmer stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

Read [Forks](forks.md) to learn how you can monitor harvesting other cryptocurrencies such as flax and chaingreen.

### FoxyPool Mode
1. Download [farmr-fedora-x86_64.rpm](https://github.com/joaquimguimaraes/farmr/releases/download/v1.5.3.2/farmr-fedora-x86_64.rpm) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
2. Open the terminal and run: ```farmr foxypoolog```/``farmr flexpool``, once you see the main screen with your id and farmer stats you're good to go.
3. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Lean how you can [enable FoxyPool balance](configuration.md#showing-foxypool-balance)/[enable Flexpool balance](configuration.md#showing-flexpool-balance) or read [Configuration](configuration.md) if you want to enable extra notifications and statistics such as response times.

### HPool Mode
1. Download [farmr-fedora-x86_64.rpm](https://github.com/joaquimguimaraes/farmr/releases/download/v1.5.3.2/farmr-fedora-x86_64.rpm) from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest), open it and install it.
2. Open the terminal and run: ```farmr hpool```, it will generate a template ``config-xch.json`` file in ``config`` directory and then it will show an error. This is expected since ``"HPool Directory"`` has not been set.
3. Edit ``config-xch.json`` in ``~/.farmr/config`` folder and set ``"HPool Directory"`` to the path where HPool is installed (there should be a file named ``config.yaml`` in this path).
4. Run ```farmr hpool``` again. Once you see the main screen with your id and stats you're good to go.
5. Link device to your discord account as shown in [First Time](./usage.md#First-time)

farmr's files are installed to ``~/.farmr``

Read [Configuration](configuration.md#showing-hpool-balance) if you want it to show total balance, settled and unsettled balance from HPool's website.

