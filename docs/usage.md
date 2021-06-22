## First time
The farmr client will generate an id for your device. 
After you've logged in to [farmr.net](https://farmr.net), you can link this device by clicking on "Add device" in the upper right corner of the dashboard, where you can copy and paste the random id (e.g.: ``e134104c-0e2e-49e0-a832-985c5a5e4516``) and then click "Add".

![tutorial](https://user-images.githubusercontent.com/82336674/121625132-c4adca00-ca6a-11eb-8906-c3d90bbf85c0.gif)

Alternatively, you can link this device to your discord account by heading to [Swar's Chia Community](https://discord.gg/q5T4QbwcnH) and sending the following message:
```
!chia link [your-client-id]
```
The client will save your id in its cache file (``.farmr_cache.json``), so you only need to run this command once per device. Mind you that you will need to do this again if this file gets deleted/corrupt.

## Usage
If your device was linked sucessfully, you will see two new tiles appear from the left (may need to refresh page). One called ``Farm`` and the other with the name of your newly added device.
``Farm`` tile is the overall statistics for your farm (multiple devices), while the other tiles will show individual statistics for each device that is linked to your account.

 Alternatively, you can use `` !chia `` in discord to see your farm summary, or `` !chia full `` to display additional statistics about it and `` !chia workers `` to show them per farmer/harvester.
To see the full list of commands you can use, type: `` !chia help ``

You **must not close the clients' console window** as doing that will kill the client and it will stop sending statistics. If you do so, open it again.
Press ``ctrl+c`` when you want to close the client. You must reopen it after restarting your computer.
