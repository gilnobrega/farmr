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

async function checkNotifs() {
    var mysql = require('mysql');
    var connection = mysql.createConnection({
        host: 'localhost',
        user: process.env.MYSQL_USER,
        password: process.env.MYSQL_PASSWORD,
        database: 'chiabot'
    });

    connection.connect();

    while (true) {

        connection.query('SELECT notificationID,user,type from notifications', async function (error, results, fields) {
            if (error) throw error;

            await results.forEach(async function (result) {
                var notificationID = result['notificationID'];
                var userID = result['user'];
                var type = result['type'];

                console.log(userID);

                //sends notification
                await sendmsg(userID, type);

                connection.query('DELETE from notifications where notificationID=' + notificationID, function (error1, results1, fields1) { });

            });


        });

        //sleep 1 minute
        await sleep(1 * 60 * 1000);

    }
    
    connection.end();
}

//https://stackoverflow.com/questions/30514584/delay-each-loop-iteration-in-node-js-async
async function sleep(millis) {
    return new Promise(resolve => setTimeout(resolve, millis));
}





