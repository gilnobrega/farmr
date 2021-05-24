const { Client, MessageEmbed } = require('discord.js');
const Discord = require("discord.js");
const request = require("request");
const fs = require("fs");
const { exec } = require("child_process");
module.exports = (client) => {

	//executes shell command
	client.execute = (command, msg) => {
	    exec(command, {
	        cwd: "../server/"
	    }, (error, stdout, stderr) => {
	        if (error) {
	            console.log(`error: ${error.message}`);
	            return;
	        }
	        if (stderr) {
	            console.log(`stderr: ${stderr}`);
	            return;
	        }

	        output = stdout.split(';;'); //splits when ;; appears (workers)
	        console.log(output.length);
	        output.forEach(worker => {

	            var array = worker.split('--');

	            var text = array[0];
	            lastUpdated = "";

	            if (array.length == 2) {
	                lastUpdated = array[1];
	            }

	            if (text !== null && text !== '' && text.length > 0) {
	                const embed = new MessageEmbed()
	                    .setColor(0x40ab5c)
	                    .setDescription(text)
	                    .setFooter(lastUpdated);

	                msg.channel.send(embed).then(sentmsg => {

	                    if (msg.channel.type != "dm") {
	                        setTimeout(() => msg.delete().catch(), client.minsTimeout * 60 * 1000);
	                        setTimeout(() => sentmsg.delete().catch(), client.minsTimeout * 60 * 1000);
	                    }
	                }).catch();
	            }

	        });

	        console.log(msg.author.id);

	    });
	}
	
	//Links a new user
	client.linkUser = (id, user, msg) => {
	    var mysql = require('mysql2');
	    var connection = mysql.createConnection({
	        host: 'localhost',
	        user: process.env.MYSQL_USER,
	        password: process.env.MYSQL_PASSWORD,
	        database: 'chiabot'
	    });

	    var idEscaped = mysql.escape(id);
	    var userEscaped = mysql.escape(user);
	    console.log(idEscaped);

	    connection.connect();

	    connection.query(" INSERT INTO farms (id, data, user) VALUES (" + idEscaped + ", ';;', " + userEscaped + ") ON DUPLICATE KEY UPDATE user=IF(user='none'," + userEscaped + ", user);", function (error, results, fields) {

	        const embed = new MessageEmbed()
	            .setColor(0x40ab5c)
	            .setTitle("Linked ID to your Discord account successfully")
	            .setDescription("");
	        msg.channel.send(embed).then(sentmsg => {

	            if (msg.channel.type != "dm") {
	                setTimeout(() => msg.delete().catch(), 1);
	                setTimeout(() => sentmsg.delete().catch(), client.minsTimeout * 60 * 1000);
	            }
	        }).catch();
	    });

	    connection.end();
	}
	
	client.loadCommand = (commandName) => {
		try {
			console.log(`Loading Command: ${commandName}`);
			const props = require(`../commands/${commandName}`);
			if (props.init) {
				props.init(client);
			}
			client.commands.set(props.help.name, props);
			props.conf.aliases.forEach(alias => {
				client.aliases.set(alias, props.help.name);
			});
			return false;
		} catch (e) {
			return `Unable to load command ${commandName}: ${e}`;
		}
	};

	client.unloadCommand = async(commandName) => {
		let command;
		if (client.commands.has(commandName)) {
			command = client.commands.get(commandName);
		} else if (client.aliases.has(commandName)) {
			command = client.commands.get(client.aliases.get(commandName));
		}
		if (!command)
			return `The command \`${commandName}\` doesn"t seem to exist, nor is it an alias. Try again!`;

		if (command.shutdown) {
			await command.shutdown(client);
		}
		const mod = require.cache[require.resolve(`../commands/${commandName}`)];
		delete require.cache[require.resolve(`../commands/${commandName}.js`)];
		for (let i = 0; i < mod.parent.children.length; i++) {
			if (mod.parent.children[i] === mod) {
				mod.parent.children.splice(i, 1);
				break;
			}
		}
		return false;
	};


	client.delay = async function delay(delayInms) {
		return new Promise(resolve => {
			setTimeout(() => {
				resolve(2);
			}, delayInms);
		});
	};
	
	// <String>.toPropercase() returns a proper-cased string such as:
	// "Mary had a little lamb".toProperCase() returns "Mary Had A Little Lamb"
	Object.defineProperty(String.prototype, "toProperCase", {
		value: function () {
			return this.replace(/([^\W_]+[^\s-]*) */g, (txt) => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());
		}
	});

};
