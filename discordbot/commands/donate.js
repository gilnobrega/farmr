const { Discord, MessageEmbed } = require('discord.js');

exports.run = (client, message, args) => {
const embed = new MessageEmbed()
        .setColor(0x40ab5c)
        .setTitle("Donate to @joaquimguimaraes")
        .setURL("https://github.com/joaquimguimaraes/chiabot#donate")
        .setDescription(
          "XCH: xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9\nETH: 0x340281CbAd30702aF6dCA467e4f2524916bb9D61")
        .setImage("https://i.ibb.co/yhcqWWc/D42-ECA8-A-55-E2-499-B-BBF8-52176-B5190-A2.jpg");
message.channel.send(embed);
};

exports.conf = {
	enabled: true,
	guildOnly: false,
	aliases: ['donation', 'chia donate', 'chia donation'],
	permLevel: 0,
	deleteCommand: false,
	cooldown: 10,
	filtered_channels: []
};

exports.cooldown = {};

exports.help = {
	name: "donate",
	category: "Other",
	description: "Displays donation links",
	usage: "donate"
};
