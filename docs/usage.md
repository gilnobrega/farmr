# Usage
If your device was linked sucessfully, you will see two new tiles appear from the left (may need to refresh page). One called ``Farm`` and the other with the name of your newly added device.
``Farm`` tile is the overall statistics for your farm (multiple devices), while the other tiles will show individual statistics for each device that is linked to your account.

 Alternatively, you can use `` !chia `` in discord to see your farm summary, or `` !chia full `` to display additional statistics about it and `` !chia workers `` to show them per farmer/harvester.
To see the full list of commands you can use, type: `` !chia help ``

You **must not close the clients' console window** as doing that will kill the client and it will stop sending statistics. If you do so, open it again.
Press ``ctrl+c`` when you want to close the client. You must reopen it after restarting your computer.

## Pools
### FoxyPool (chia-og) Mode
farmr can show your pending and collateral balances from FoxyPool.
1. Follow the Install Instructions according to your platform.
1. Run ``foxypoolog.exe`` or ``foxypoolog.sh`` for initialization then exit
1. Set ``"Pool Public Key"``in ``config/config-xch.json``
    - farmr client uses this key locally and it is never sent to farmr's servers
1. Reopen ``foxypoolog.exe`` or ``foxypoolog.sh``

### HPool Mode
farmr can show basic stats from HPool.
1. Follow the Install Instructions according to your platform.
1. Run ``hpool.exe`` or ``hpool.sh`` for initialization then exit
1. Set ``"HPool Directory"`` and ``"HPool Auth Token"`` in ``config/config-xch.json``
    - More information in [Configuration Docs](./docs/configuration.md#HPool%20Mode)
    - farmr client uses this auth token locally and it is never sent to farmr's servers
1. Reopen ``hpool.exe`` or ``hpool.sh``