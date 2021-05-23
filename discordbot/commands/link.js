const Discord = require("discord.js");
exports.run = (client, message, args) => {
    var id = args[0];
    var user = message.author.id;

    client.linkUser(id, user, message);
};

exports.conf = {
    enabled: true,
    guildOnly: false,
    aliases: ['chia link'],
    permLevel: 0,
    deleteCommand: false,
    cooldown: 10,
    filtered_channels: []
};

exports.cooldown = {};

exports.help = {
    name: "link",
    category: "Chia Commands",
    description: "Links a new ChiaBot user",
    usage: "link <ID>"
};