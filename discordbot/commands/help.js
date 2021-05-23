const Discord = require("discord.js");
exports.run = (client, message, args) => {
	
	//Temporary
	const permission = 0;
	
	let config = client.config;
	if (!args[0]) {
		// Filter all commands by which are available for the user's level, using the <Collection>.filter() method.
		const myCommands = client.commands.filter(cmd => permission >= cmd.conf.permLevel);

		// Here we have to get the command names only, and we use that array to get the longest name.
		// This make the help commands "aligned" in the output.
		const commandNames = myCommands.keyArray();
		const longest = commandNames.reduce((long, str) => Math.max(long, str.length), 0);

		let currentCategory = "";
		let output = `= Command List =\n\n[Use ${config.PREFIX}help <commandname> for details]\n`;
		const sorted = myCommands.array().sort((p, c) => p.help.category > c.help.category ? 1 : p.help.name > c.help.name && p.help.category === c.help.category ? 1 : -1);
		sorted.forEach(c => {
			const cat = c.help.category.toProperCase();
			if (currentCategory !== cat) {
				output += `\u200b\n== ${cat} ==\n`;
				currentCategory = cat;
			}
			output += `${config.PREFIX}${c.help.name}${" ".repeat(longest - c.help.name.length)} :: ${c.help.description}\n`;
		});
		message.channel.send(output, {
			code: "asciidoc",
			split: {
				char: "\u200b"
			}
		});
	} else {
		// Show individual command's help.
		let command = args[0];
		if (client.commands.has(command)) {
			command = client.commands.get(command);
			
			let aliases = '';
			
			for (const alias of command.conf.aliases) {
				aliases += `"${alias}"\n`
			}

			const embed = new Discord.MessageEmbed()
				.setTitle(`**${client.user.username} Command Guide**`)
				.setDescription(`__**Command Name**__
				*${command.help.name}*
				
				__**Description**__ 
				*${command.help.description}*
				__**Usage**__ 
				${command.help.usage}
				__**Aliases**__
				${aliases}
				`);

			message.channel.send(embed);
		}
	}
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ["help", 'chia help'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 0,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "help",
	category: "System",
	description: "Displays all the available commands for your permission level.",
	usage: "help [command]"
};
