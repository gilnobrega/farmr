
### Troubleshooting

##### My farmer/harvester doesn't have plots. Can I still use farmr?
Yes, your client will add itself when chia completes a plot.

If the client crashes:
##### Is your chia farm running? 
  You can check this by running ` chia farm summary `, if it shows "Status: Farming", then it is.
##### Are your plot drives mounted?
  If they're not, then mount them.
##### Does your user have permission to access the folders where plots are stored?
  farmr will not be able to list your plots if their folder was mounted as root.

##### What if I have two or more farmers?
  Run one of them as a farmer and the others as harvesters.
 
##### Help, I linked the same device twice and it's showing two devices.
  Inactive clients will expire after 15 minutes.
  