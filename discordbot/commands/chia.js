const Discord = require("discord.js");
exports.run = (client, message, args) => {
client.execute(`../server/chiabot_server.exe ${message.author.id}`, message, true);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['chia'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "chia",
	category: "Chia Commands",
	description: "Displays your basic farming stats",
	usage: "chia"
};
