<?php

include('db.php'); //initializes $conn = new mysqli();

if ($conn -> connect_errno)
{
echo "Failed to connect to database!";
}

if ( isset($_GET['user']))
{
 $user = $conn -> real_escape_string($_GET['user']);

 $command = " SELECT data FROM farms WHERE user='" . $user . "' AND `lastUpdated` BETWEEN DATE_SUB(NOW(), INTERVAL 15 MINUTE) AND NOW() ORDER BY lastUpdated DESC;";
 $result = $conn -> query($command);

 while ($row = $result -> fetch_row()) {
   echo "[" . $row[0] . "];;";
}

}

$conn -> close();
?>
