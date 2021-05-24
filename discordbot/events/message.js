module.exports = async (client, message) => {
    //Ignore other bots (and self)
    if (message.author.bot)
        return;

    //Sanity check
    if (message.content.length === 1) {
        return;
    }

    let config = client.config;

    if (message.content.toLowerCase().indexOf(config.PREFIX) === 0) {

        //Todo: Permission levels?
        const permission = 0;

        //Grab our arguments & command name
        const args = message.content.slice(config.PREFIX.length).trim().split(/ +/g);
        let command = args.shift().toLowerCase();

        //Hacky fix for recognizing old command structure
        if (command == "chia" && args[0]) {
            command = `chia ${args[0]}`;

            //Shift
            args.shift();
        }

        //If the member on a guild is invisible or not cached, fetch them.
        if (message.guild && !message.member)
            await message.guild.fetchMember(message.author);

        //Is this a valid command, or command alias?
        const cmd = client.commands.get(command) || client.commands.get(client.aliases.get(command));
        if (!cmd)
            return;

        //Are we allowed to use this?
        if (permission < cmd.conf.permLevel)
            return message.channel.send("You do not have access to this command");

        //Can we use this command in a DM?
        if (cmd && !message.guild && cmd.conf.guildOnly)
            return message.channel.send("This command is unavailable via private message. Please run this command in a guild.");

        message.flags = [];
        while (args[0] && args[0][0] === "-") {
            message.flags.push(args.shift().slice(1));
        }

        //Does this command have a cooldown period?
        //TEMPORARILY DISABLED FOR DMS
        if (message.channel.type != "dm" && cmd.conf.cooldown > 0) {
            let member = message.member;

            let coolObj = {
                member: member,
                cmd: cmd.help.name,
                time: (new Date().getTime())
            };

            let cooldown = client.cooldown[cmd.help.name.toLowerCase()][member];

            if (cooldown) {
                var currTime = (new Date().getTime())
                var timeSince = (currTime - cooldown) / 1000;
                if (timeSince < cmd.conf.cooldown) {
                    var until = (cmd.conf.cooldown - timeSince);
                    var untilParsed = Math.ceil(until);
                    return message.reply(`This command is on cooldown! Try again in ${untilParsed} second(s).`);
                } else {
                    client.cooldown[cmd.help.name.toLowerCase()][member] = (new Date().getTime())
                }
            } else {
                client.cooldown[cmd.help.name.toLowerCase()][member] = (new Date().getTime())
            }
        }

        //Should the command/syntax be auto-deleted?
        if (cmd.conf.deleteCommand) {
            message.delete({
                timeout: 1000,
                reason: 'It had to be done.'
            }).catch();
        }

        //Filtered channel?
        if (cmd.conf.filtered_channels.includes(message.channel.id))
            return message.reply("Oh no! This command is too powerful for this channel!\nPlease run it in <#838813418793336832> so we can keep this channel free of SPAM.");

        //We made it, Run it!
        await cmd.run(client, message, args);

    }
};