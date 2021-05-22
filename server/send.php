<?php

include('db.php');

if ($conn -> connect_errno)
{
echo "Failed to connect to database!";
}

if ( isset($_POST['id']) && isset($_POST['data']))
{
 $id = $conn -> real_escape_string($_POST['id']);
 $data = $conn -> real_escape_string($_POST['data']);
 $name = $conn -> real_escape_string($_POST['name']);

 $command = " INSERT INTO farms (id, data, user) VALUES ('" . $id . "','" . $data . "', 'none') ON DUPLICATE KEY UPDATE data='" . $data . "';";
 $result = $conn -> query($command);

    //if one of these variables are set, then it needs to find user id 
    if (isset($_POST['balance']) || isset($_POST['lastPlot']) || isset($_POST['notifyOffline']) || isset($_POST['isFarming']))
    {
        $user = "none";

        //searches for user id which is linked to client id, so that the discord bot can message that person
        $getUser = " SELECT user from farms WHERE id='" . $id . "'";
        $result2 = $conn -> query($getUser);

        while ($row = $result2 -> fetch_row())
        {
            $user = $row[0];
        }

        if (isset($_POST['lastPlot']) && $_POST['lastPlot'] != "0")
        {

            $lastPlot = $conn -> real_escape_string($_POST['lastPlot']);

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
                $conn -> query($command2);

            } 
            //If there is an entry with last plot and its different from previous registered plot id then update it and notify user
            else if (($previousID !== $lastPlot) && (gettype($previousID) === gettype($lastPlot)))
            {
                $command2 = " UPDATE lastplots set lastplot='" . $lastPlot . "' WHERE id='" . $id . "';";
                $conn -> query($command2);

                //send
                $arg = "plot";
                //send notification
                $commandNotif = " INSERT INTO notifications(user,type,name) VALUES ('" . $user . "', '" . $arg . "', '" . $name . "');";
                $conn -> query($commandNotif);
            }

        }

        if (isset($_POST['balance']))
        {
            $balance = floatval($conn -> real_escape_string($_POST['balance']));

            //checks stored balance, or if there is an entry in the database
            $checkBalance = "SELECT balance from balances WHERE id='" . $id . "';";
            $result4 = $conn -> query($checkBalance);

            $existsBalance = false;
            $previousBalance = floatval('0.0');

            while ($row = $result4 -> fetch_row())
            {
                $existsBalance = true;
                $previousBalance = floatval($row[0]);
            }

            $command3 = "";

            //If there doesnt exist an entry with last balance
            if (!$existsBalance)
            {
                $command3 = " INSERT INTO balances (id, balance) VALUES ('" . $id . "','" . $balance . "');";
                $conn -> query($command3);

            } 
            //If there is an entry with last balance and its a higher value than previous registered balance then update it and notify user
            else if ($balance > $previousBalance)
            {
                $command3 = " UPDATE balances set balance='" . $balance . "' WHERE id='" . $id . "';";
                $conn -> query($command3);

                //send
                $arg = "block";                
                //send notification
                $commandNotif = " INSERT INTO notifications(user,type,name) VALUES ('" . $user . "', '" . $arg . "', '" . $name . "');";
                $conn -> query($commandNotif);
            }

        }

        if (isset($_POST['notifyOffline']))
        {
            $notify = $conn -> real_escape_string($_POST['notifyOffline']);

            $command4 = " INSERT INTO offline (id, notify, name) VALUES ('" . $id . "','" . $notify . "', '" . $name . "') ON DUPLICATE KEY UPDATE notify='" . $notify . "', name='" . $name . "' ;";
            $conn -> query($command4);

        }

        if (isset($_POST['isFarming']))
        {

            $isFarming = (int) $conn -> real_escape_string($_POST['isFarming']);

            $checkIfFarming = "SELECT isfarming from statuses WHERE id='" . $id . "';";
            $result5 = $conn -> query($checkIfFarming);

            $existsEntry = false;
            $previousValue = "0";

            while ($row = $result5 -> fetch_row())
            {
                $existsEntry = true;
                $previousValue = (int) $row[0];
            }

            $command5 = "";

            //If there doesnt exist an entry with last isfarming
            if (!$existsEntry)
            {
                $command5 = " INSERT INTO statuses (id, isfarming) VALUES ('" . $id . "','" . $isFarming . "');";
                $conn -> query($command5);

            } 
            //If there is an entry with last plot and its different from previous registered plot id then update it and notify user
            else if (($isFarming !== $previousValue) && (gettype($isFarming) === gettype($previousValue)))
            {
                $command5 = " UPDATE statuses set isfarming='" . $isFarming . "' WHERE id='" . $id . "';";
                $conn -> query($command5);
 
                //send notification if client was previously farming but now its not
                if ($previousValue === 1)
                {
                    $arg = "stopped";
                    //send notification
                    $commandNotif = " INSERT INTO notifications(user,type,name) VALUES ('" . $user . "', '" . $arg . "', '" . $name . "');";
                    $conn -> query($commandNotif);
                }
            }

        }
    
    }
}

$conn -> close();
?>
