const Discord = require("discord.js");
exports.run = (client, message, args) => {
    message.channel.send("<@96884333524041728> <:monkaStab:833539425405370408>");
};

exports.conf = {
    enabled: true,
    guildOnly: false,
    aliases: ['allenn', 'allen'],
    permLevel: 0,
    deleteCommand: false,
    cooldown: 60,
    filtered_channels: []
};

exports.cooldown = {};

exports.help = {
    name: "allenn",
    category: "Other",
    description: "Calls Allen",
    usage: "allenn"
};