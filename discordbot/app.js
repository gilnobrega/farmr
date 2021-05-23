const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');
const Enmap = require("enmap");
const fs = require("fs");

const client = new Discord.Client({
		disableEveryone: false,
		disabledEvents: ['TYPING_START'],
		fetchAllMembers: false,
		partials: ['MESSAGE', 'CHANNEL', 'REACTION']
});

require('dotenv').config();
require("./modules/helpers.js")(client);


const etherscanAPIKey = process.env.ETHERSCAN_TOKEN; //loads etherscan api key from environment variables file

//initializes our bot
async function init() {
	
	client.config = process.env;
	client.minsTimeout = 15; //message timeout in mins
	
	//Load our events!
	console.log("Loading events and commands....");
	fs.readdir("./events/", (err, files) => {
	    if (err)
	        return console.error(err);
	    files.forEach(file => {
	        const event = require(`./events/${file}`);
	        let eventName = file.split(".")[0];
	        client.on(eventName, event.bind(null, client));
	    });
	});
	
	//Load our commands!
	client.commands = new Enmap();
	client.aliases = new Enmap();
	client.cooldown = {};

	fs.readdir("./commands/", (err, files) => {
	    if (err)
	        return console.error(err);
	    files.forEach(file => {
	        if (!file.endsWith(".js"))
	            return;
	        let props = require(`./commands/${file}`);
	        let commandName = file.split(".")[0];

	        props.conf.aliases.forEach(alias => {
	            client.aliases.set(alias, props.help.name);
	        });

	        client.cooldown[commandName.toLowerCase()] = {};

	        console.log(`Attempting to load command ${commandName}`);
	        client.commands.set(commandName, props);
	    });
	});
	
	client.login(client.config.BOT_TOKEN2); //loads discord token from environment variables file

}

//Let's go to work
init();




