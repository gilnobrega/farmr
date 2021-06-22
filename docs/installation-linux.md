
### Installing farmr on Linux

1. Download ``farmr-linux-x86_64.tar.gz`` from the [latest release](https://github.com/joaquimguimaraes/farmr/releases/latest) and extract it to an **empty** folder.
2. Open the following file:
      - If you're setting up a **farmer/full-node** Open ``farmer.sh``, once you see the main screen with your id and farmer stats you're good to go.
      - If you're setting up a **harvester** Open ``harvester.sh``, once you see the main screen with your id and harvester stats you're good to go.
3. Link your device to your discord account as shown in [First Time](./usage.md#First-time)

If you can't open ``farmer.sh`` or ``harvester.sh`` from file explorer you can run this command:
```
gsettings set org.gnome.nautilus.preferences executable-text-activation ask
```
Then reopen file explorer in the folder where ``farmr-linux-amd64.tar.gz`` was extracted to. You should be able to double click ``farmer.sh`` or ``harvester.sh`` and let it "Run in terminal" when asked to.

