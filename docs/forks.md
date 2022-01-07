## Forks
To enable a configured fork, you must rename the template file to allow farmr to generate a config.

1. In the `blockchain` folder, rename `###.json.template` to `###.json` (e.g.: rename ```xfx.json.template``` to ```xfx.json```).
1. Restart farmr, and provide the path if prompted

### Creating Template Files
In the event that your coin is not listed here, you will need to create a template file yourself.

1. Create the file with the proper name
1. Place the boilerplate inside of this file
    ```
{
  "Binary Name": "chia",
  "Currency Symbol": "XCH",
  "Minor Currency Symbol": "mojo",
  "Major to Minor Multiplier": 1e12,
  "Net": "mainnet",
  "Block Rewards": 2.0,
  "Blocks Per 10 Minutes": 32.0,
  "Online Config": true,
  "Ports": {
    "harvester": 8560,
    "farmer": 8559,
    "fullNode": 8555,
    "wallet": 9256,
    "daemon": 55400
  },
  "Report Interval": 600,
  "Log Parse Interval": 5
}
    ```
1. Edit the values as shown below. All defaults below are the `Chia-Network/chia-blockchain` values 
1. Ensure it is working in [farmr](https://farmr.net/#/)
    - If you are feeling adventurous and want to help the community grow, submit a PR to [farmr's Github](https://github.com/joaquimguimaraes/farmr/pulls)

#### Binary Name
Command used to execute from the CLI.
- Chia Example: `chia`

#### Folder Name
OPTIONAL: Name of the root folder of configuration/log files
- Chia Example: `.chia`

#### Currency Symbol
Symbol to use to recognize the coin.
- Chia Example: `XCH`

#### Minor Currency Symbol
Symbol to use to recognize smaller parts of the coin.
- Chia Example: `mojo`

#### Net
What net to retrieve data from.
- Default: `mainnet`

#### Block Rewards
How much is won per block?
- Chia Example: `2.0`

#### Blocks Per 10 Minutes
How many Blocks occur per 10 Minutes?
- Chia Example: `32.0`

#### Config Path
OPTIONAL: Path to the config files.
- Chia Example:
    ```
    Linux: `/home/user/.chia/mainnet/config`
    Windows: `C:\\Users\\USER\\.chia\\mainnet\\config`
    ```

#### Log Path
OPTIONAL: to the log files.
- Chia Example:
    ```
    Linux: `/home/user/.chia/mainnet/log`
    Windows: `C:\\Users\\USER\\.chia\\mainnet\\log`
    ```

#### Online Config
OPTIONAL: Allows configuring settings through farmr.net dashboard.
Defaults to true.
When false, these can be set in local ```config-###.json``` files.

#### Ports
RPC Service Ports

#### Report Interval
OPTIONAL: Interval between farmr reports in seconds. 
Defaults to 10 minutes (600 seconds). 
May not be shorter than 1 minute (60 seconds) or higher than 30 minutes (1800 seconds).

#### Log Parse Interval
OPTIONAL: Interval between debug.log parses 
Defaults to 5 seconds. 
