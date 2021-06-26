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
    "Binary Name": "",
    "Currency Symbol": "",
    "Minor Currency Symbol": "",
    "Net": "mainnet",
    "Block Rewards": 0,
    "Blocks Per 10 Minutes": 0,
    "Config Path": "/home/user/.goji-blockchain/mainnet/config",
    "Log Path": "/home/user/.goji-blockchain/mainnet/log"
}
```
1. Edit the values as shown below. All defaults below are the `Chia-Network/chia-blockchain` values 

#### Binary Name
Command used to execute from the CLI.
- Chia Example: `chia`

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
Path to the config files.
- Chia Example:
    ```
    Linux: `/home/user/.chia/mainnet/config`
    Windows: `C:\\Users\\USER\\.chia\\mainnet\\config`
    ```

#### Log Path
Path to the log files.
- Chia Example:
    ```
    Linux: `/home/user/.chia/mainnet/log`
    Windows: `C:\\Users\\USER\\.chia\\mainnet\\log`
    ```