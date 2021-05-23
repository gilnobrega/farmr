const Discord = require("discord.js");
exports.run = (client, message, args) => {
    message.reply("https://chiabot.znc.sh/read.php?user=" + message.author.id);
};

exports.conf = {
    enabled: true,
    guildOnly: false,
    aliases: ['chia api'],
    permLevel: 0,
    deleteCommand: false,
    cooldown: 10,
    filtered_channels: []
};

exports.cooldown = {};

exports.help = {
    name: "api",
    category: "Chia Commands",
    description: "Provides a link with your farm data",
    usage: "api"
};