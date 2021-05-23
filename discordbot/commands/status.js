const Discord = require("discord.js");
exports.run = (client, message, args) => {
client.execute(`../server/chiabot_server.exe status`, message, true);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['chia status', 'status'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "status",
	category: "Chia Commands",
	description: "Displays current ChiaBot status",
	usage: "status"
};
