
## FAQ

##### Are you going to steal my keys?
No. The only commands issued by farmr client is ``chia farm summary`` for farmer stats, ``chia wallet show`` for wallet balance parsing and ``chia show -c`` to count how many peers are connected to your full node. It does not use Chia's RCP servers, therefore it doesn't even need your private key.

##### How can I trust you?
This project is open-source, so you don't have to trust me. Read the code yourself :)
Besides, every binary is built by a github action and signed with a GPG key.

##### What data is collected?
You can see the data that's currently tied to your discord ID with ``!chia api``
Your wallet address is not sent to the server so your data remains anonymous (that is, except being linked to your discord ID).

##### What if I don't want my data to be stored in your server anymore?
Simple, stop using it. All data will be deleted 15 minutes after your client sent its last report.
