const Discord = require("discord.js");
exports.run = (client, message, args) => {
client.execute(`../server/chiabot_server.exe price`, message, true);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['chia price', 'price'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "price",
	category: "Chia Commands",
	description: "Displays current XCH price",
	usage: "price"
};
