const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');

require('dotenv').config();

const client = new Discord.Client();

client.on('ready', () => {
    console.log('Bot is ready');

    checkNotifs();
});

client.login(process.env.BOT_TOKEN2); //loads discord token from environment variables file

const { exit } = require('process');

async function sendmsg(id, command) {

    if (id !== "none") {

        if (command == "block") message = ":money_mouth: Your farm just found a block!";
        else if (command == "plot") message = ":tada: Your farm just completed another plot.";
        else if (command == "offline") message = ":skull_crossbones: Lost connection to farmer/harvester!";
        else if (command == "stopped") message = ":scream: Your farmer stopped farming!";
        else exit();

        const user = await client.users.fetch(id).catch(() => null);

        if (!user) console.log("User not found:(");

        await user.send(message).catch(() => {
            console.log("User has DMs closed or has no mutual servers with the bot:(");
        });

    }

}

var db_config = {
    host: 'localhost',
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: 'chiabot'
};

var connection;

var mysql = require('mysql');

//http://sudoall.com/node-js-handling-mysql-disconnects/
function handleDisconnect() {
    connection = mysql.createConnection(db_config); // Recreate the connection, since
    // the old one cannot be reused.

    connection.connect(function (err) {              // The server is either down
        if (err) {                                     // or restarting (takes a while sometimes).
            console.log('error when connecting to db:', err);
            setTimeout(handleDisconnect, 2000); // We introduce a delay before attempting to reconnect,
        }                                     // to avoid a hot loop, and to allow our node script to
    });                                     // process asynchronous requests in the meantime.
    // If you're also serving http, display a 503 error.
    connection.on('error', function (err) {
        console.log('db error', err);
        setTimeout(handleDisconnect, 2000); // We introduce a delay before attempting to reconnect,
        handleDisconnect();                         // lost due to either server restart, or a
    });
}

async function checkNotifs() {

    while (true) {

        try {
            handleDisconnect();
            connection.query('SELECT notificationID,user,type from notifications', async function (error, results, fields) {
                if (error) console.log(error);
                else {
                    await results.forEach(async function (result) {
                        var notificationID = result['notificationID'];
                        var userID = result['user'];
                        var type = result['type'];

                        connection.query('DELETE from notifications where notificationID=' + notificationID, function (error1, results1, fields1) { });

                        console.log(userID);

                        //sends notification
                        await sendmsg(userID, type);

                    });
                }


            });

            updateStatus();

            //sleep 1 minute
            await sleep(1 * 60 * 1000);

            connection.end();

        }
        catch (e) {
            console.log(e);
        }
    }

}

var userCount = 0;
var devicesCount = 0;

function updateStatus() {

    connection.query(
        "SELECT user FROM farms WHERE data<>'' AND data<>';' AND user<>'none' group by user", function (error, results, fields) {
            if (error) console.log(error);
            else {
                userCount = results.length;
            }
        });


    connection.query(
        "SELECT id FROM farms WHERE data<>'' AND data<>';'", function (error, results, fields) {
            if (error) console.log(error);
            else {
                devicesCount = results.length;
            }
        });

    var status = userCount + " users, " + devicesCount + " devices";
    client.user.setActivity(status, { type: "LISTENING" });
}

//https://stackoverflow.com/questions/30514584/delay-each-loop-iteration-in-node-js-async
async function sleep(millis) {
    return new Promise(resolve => setTimeout(resolve, millis));
}





