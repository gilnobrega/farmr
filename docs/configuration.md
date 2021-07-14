# Configuration
You can configure each device by pressing the settings button (on the top right corner) when that device is selected.

![settings-button](https://i.imgur.com/tANnBeT.png)

Then its settings menu will appear as follows:

![image](https://i.imgur.com/AqPoFwA.png)

These settings will be applied with the next report (may take up to 10 minutes)

Alternatively, you may opt to configure your device locally. To do so, set ``"Online Config"`` to ``false`` in your blockchain file (e.g.: ``blockchain/xch.json``). This will generate a configuration file in ``config`` folder (e.g.: ``config/config-xch.json``)

## Options

### Name your client
You can name your client by changing `` "Name": "Harvester",`` to ``"name": "YourFarmer",`` (notice **quote marks**). This will identify the client as ``YourFarmer`` in `` !chia workers ``.

#### Choose your preferred currency
Replace ``"USD"`` with any of the following 3-digit symbols: ‘USD’, 'EUR', 'CAD', 'GBP', 'AUD', 'SGD', 'JPY', 'INR', 'RMB', 'CNY', 'CHF', 'HKD', 'BRL', 'DKK', 'NZD', 'TRY', 'ETH', 'BTC', 'ETC', 'TWD', 'WON'.

#### Sharing farmed XCH Balance
Set ``Show Farmed XCH`` to ``false`` if you do not want your farmed balance to be reported to the server. Setting this to false will disable Block notifications.

#### Sharing Wallet Balance
Set ``Show Wallet Balance`` to ``true`` if you want your wallet balance to be displayed.

#### Cold Wallet Balance and Notifications (only for chia/flax)
Set ``Cold Wallet Address`` to some public address (e.g.: ``"xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9"``) if you want your cold wallet balance to be displayed. Set ``"Send Cold Wallet Balance Notifications"`` to ``false`` if you do not wish to be notified about incoming xch or xfx (such as block rewards).
You can add multiple addresses if they are separated by a comma (e.g.: ``"xfx1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qz5ppr8,xfx1xlvrj6erlgu2fmaumzxxdzsxrrz59n7rx3n8eh7wt9xtqulv53hq8qfden"``).

#### Block Notifications
Set ``Block Notifications`` to ``false`` if you do not wish to be notified when your farmer finds a block.

#### Plot Notifications
Set ``Plot Notifications`` to ``true`` if you wish to be notified when your farmer/harvester completes a plot.

#### Hard Drive Notifications
Set ``Hard Drive Notifications`` to ``false`` if you don't want to be notified when your farmer/harvester loses connection to one of its drives.

#### Offline Notifications
Set ``Offline Notifications`` to ``true`` if you wish to be notified when your farmer/harvester loses connection.

#### Status Notifications
Set ``Farm Status Notifications`` to ``false`` if you don't want to be notified when your farmer loses sync and stops farming. If you have log parsing enabled, you will also be notified if your harvester stopped receiving challenges.

#### Chia Log Parsing
If your chia debug level is set to ``INFO`` ([find how to do that here](https://thechiafarmer.com/2021/04/20/how-to-enable-chia-logs-on-windows/)), setting ``Parse Logs`` to ``true`` will enable extra stats, such as number of challenges in the last 24 hours, max, min and average challenge response times, incomplete SubSlots, and number of short losses of sync events.

#### Multiple Discord Users
Change ``Number of Discord Users`` if you would like to link your farmer/harvester to more than one discord user. It will generate one unique ID per user.
You may delete ``config.json`` and ``.farmr_cache.json`` to reset settings and generate new ids once the client is started again.

#### Public API
Set ``Public API`` to true if you want your data to be accessed from farmr's api page (``!chia api`` will show you your link)

#### Swar's Chia Plot Manager Integration (experimental)
If you are running Swar's Plot Manager >v0.1.0 then you can set ``"Swar's Chia Plot Manager Path"`` to the path where it's installed.
Notice that if you run it in a python venv then you must launch the farmr client in this venv. Current jobs will be displayed at the bottom of ``!chia full`` and ``!chia workers``

#### Showing FoxyPool balance
Set ``"Pool Public Key"`` to your pool public key if you want FoxyPool's pending and collateral balances to be displayed.

#### Showing Flexpool balance
Set ``"Flexpool Address"`` to your chia public address (starts with ``xch``) if you want Flexpool's balance to be displayed.

#### Showing HPool Balance

You need to set ``HPool Auth Token`` to the ``auth_key`` string in your hpool.com cookies. To see this token, open your browser and login to hpool.com, then right-click anywhere on the page and click on ``Inspect Element``, you should see a panel appear with a "Storage" tab. Right click on the string next to "auth_key" and copy that string string in ``value`` column. That's the string you should use as ``HPool Auth Token`` in farmr's ``config.json``. You should only need to update this value once every 3 months or when you logout from that device.
![image](https://user-images.githubusercontent.com/82336674/120874560-063c0200-c59f-11eb-8110-2be81469651b.png)
