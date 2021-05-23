const Discord = require("discord.js");
exports.run = (client, message, args) => {
client.execute(`../server/chiabot_server.exe ${message.author.id}  full`, message, true);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['chia full'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: ['829057822213931062']
};

exports.cooldown = {};

exports.help = {
	name: "full",
	category: "Chia Commands",
	description: "Displays your full farming stats",
	usage: "full"
};
