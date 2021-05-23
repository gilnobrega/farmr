const Discord = require("discord.js");
exports.run = (client, message, args) => {
client.execute("../server/chiabot_server.exe netspace", message, true);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['chia netspace', 'netspace'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "netspace",
	category: "Chia Commands",
	description: "Displays current netspace statistics",
	usage: "netspace"
};
