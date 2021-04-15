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

 $command = " INSERT INTO farms (id, data, user) VALUES ('" . $id . "', ';;', '" . $user . "') ON DUPLICATE KEY UPDATE user=IF(user='none','" . $user . "', user);";
 $conn -> query($command);
}

$conn -> close();
?>
