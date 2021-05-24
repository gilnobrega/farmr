const Discord = require("discord.js");
exports.run = (client, message, args) => {
    message.channel.send("https://i.ibb.co/18c3ys7/gene.jpg");
};

exports.conf = {
    enabled: true,
    guildOnly: false,
    aliases: ['codeityourself', 'doityourself', 'gene'],
    permLevel: 0,
    deleteCommand: false,
    cooldown: 30,
    filtered_channels: []
};

exports.cooldown = {};

exports.help = {
    name: "diy",
    category: "Other",
    description: "Gene Mfing Hoffman",
    usage: "diy"
};