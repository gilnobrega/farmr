<?php

include('db.php');

if ($conn -> connect_errno)
{
echo "Failed to connect to database!";
}

if ( isset($_GET['id']) && isset($_GET['user']))
{
 $id = $conn -> real_escape_string($_GET['id']);
 $user = $conn -> real_escape_string($_GET['user']);

 echo "set!";

 $command = " UPDATE farms SET user='" . $user . "' WHERE user='none' AND id='" . $id . "' ;";
 $conn -> query($command);
}

$conn -> close();
?>
