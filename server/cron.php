<?php
//This file is a cron task which runs in the server every X minutes

include('db.php'); //initializes $conn = new mysqli();

$command1 = " SELECT id,user from farms WHERE `lastUpdated` < DATE_SUB(NOW(), INTERVAL 15 MINUTE) AND data<>'';";
$result1 = $conn -> query($command1);

//Deletes data older than 15 minutes
$command2 = " UPDATE farms SET `lastUpdated` = `lastUpdated`, data='' WHERE `lastUpdated` < DATE_SUB(NOW(), INTERVAL 15 MINUTE) ;";
$result2 = $conn -> query($command2);

//Notifies users if their rig has gone offline
while ($row = $result1 -> fetch_row())
{
    $id = $row[0];
    $user = $row[1];

    $command3 = " SELECT notify from offline WHERE id='" . $id . "'";
    $result3 = $conn -> query($command3);

    while ($row3 = $result3 -> fetch_row())
    {
      $notifyOffline = $row3[0];

      //sends notification if it is linked 
      if ($notifyOffline == '1' && $user != "none")
      {
        //send
        $arg = "offline";
        //send notification
        $commandNotif = " INSERT INTO notifications(user,type) VALUES ('" . $user . "', '" . $arg . "');";
        $conn -> query($commandNotif);
      }
    }
}

$conn -> close();

?>