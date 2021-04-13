<?php

include('db.php');

if ($conn -> connect_errno)
{
echo "Failed to connect to database!";
}

if ( isset($_GET['id']) && isset($_POST['data']))
{
 $id = $conn -> real_escape_string($_GET['id']);
 $data = $conn -> real_escape_string($_POST['data']);

 $command = " INSERT INTO farms (id, data, user) VALUES ('" . $id . "','" . $data . "', 'none') ON DUPLICATE KEY UPDATE data='" . $data . "';";
 $result = $conn -> query($command);

 if (isset($_GET['lastPlot']))
 {
     $user = "none";

     $getUser = " SELECT user from farms WHERE id='" . $id . "'";
     $result2 = $conn -> query($getUser);

     while ($row = $result2 -> fetch_row())
     {
         $user = $row[0];
     }

     $lastPlot = $conn -> real_escape_string($_GET['lastPlot']);

     $checkIfPlots = "SELECT lastplot from lastplots WHERE id='" . $id . "';";
     $result3 = $conn -> query($checkIfPlots);

     $existsPlot = false;
     $previousID = "0";

     while ($row = $result3 -> fetch_row())
     {
        $existsPlot = true;
        $previousID = $row[0];
     }

     $command2 = "";

    //If there doesnt exist an entry with last plot
    if (!$existsPlot)
    {
        $command2 = " INSERT INTO lastplots (id, lastplot) VALUES ('" . $id . "','" . $lastPlot . "');";
    } 
    //If there is an entry with last plot and its different from previous registered plot id then update it and notify user
    else if ($previousID != $lastPlot)
     {
         $command2 = " UPDATE lastplots set lastplot='" . $lastPlot . "' WHERE id='" . $id . "';";

         //execute webhook
         include('webhook.php');
     }

     $conn -> query($command2);

 }
 
}

$conn -> close();
?>
