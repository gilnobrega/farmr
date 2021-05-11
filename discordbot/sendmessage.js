const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');

require('dotenv').config();

const client = new Discord.Client();

client.on('ready', () => {
    console.log('Bot is ready');

    sendmsg(process.argv);
});

client.login(process.env.BOT_TOKEN2); //loads discord token from environment variables file

const { exit } = require('process');

async function sendmsg(args) {
    var id = args[2];
    console.log(id);
    var command = args[3];

    if (command == "block") message = ":money_mouth: Your farm just found a block!";
    else if (command == "plot") message = ":tada: Your farm just completed another plot.";
    else if (command == "offline") message = ":skull_crossbones: Lost connection to farmer/harvester!";
    else if (command == "stopped") message = ":scream: Your farmer stopped farming!";
    else exit();

    const user = await client.users.fetch(id).catch(() => null);

    if (!user) console.log("User not found:(");

    await user.send(message).catch(() => {
        console.log("User has DMs closed or has no mutual servers with the bot:(");
        exit();

    });

    exit();

}




