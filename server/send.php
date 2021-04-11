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
 
 echo $command;

}

$conn -> close();
?>
