const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');

require('dotenv').config();

const client = new Discord.Client();

const etherscanAPIKey = process.env.ETHERSCAN_TOKEN; //loads etherscan api key from environment variables file

client.on('ready', () => {
  console.log('Bot is ready');
});

client.login(process.env.BOT_TOKEN2); //loads discord token from environment variables file

const { exec } = require("child_process");

const minsTimeout = 15; //message timeout in mins

//executes shell command
function runCommand(command, msg) {
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.log(`error: ${error.message}`);
      return;
    }
    if (stderr) {
      console.log(`stderr: ${stderr}`);
      return;
    }

    output = stdout.split(';;'); //splits when ;; appears (workers)
    console.log(output.length);
    output.forEach(worker => {

      var array = worker.split('--');

      var text = array[0];
      lastUpdated = "";

      if (array.length == 2) {
        lastUpdated = array[1];
      }

      if (text !== null && text !== '' && text.length > 0)
      {
        const embed = new MessageEmbed()
          .setColor(0x40ab5c)
          .setDescription(text)
          .setFooter(lastUpdated);

        msg.channel.send(embed).then(sentmsg => {

          if (msg.channel.type != "dm") {
            setTimeout(() => msg.delete().catch(), minsTimeout * 60 * 1000);
            setTimeout(() => sentmsg.delete().catch(), minsTimeout * 60 * 1000);
          }
        }).catch(); 
      }

    });

    console.log(msg.author.id);

  });
}

function linkUser (id, user, msg)
{
  var mysql = require('mysql');
    var connection = mysql.createConnection({
        host: 'localhost',
        user: process.env.MYSQL_USER,
        password: process.env.MYSQL_PASSWORD,
        database: 'chiabot'
    });

    var idEscaped = mysql.escape(id);
    var userEscaped = mysql.escape(user);
    console.log(idEscaped);

    connection.connect();

    connection.query(" INSERT INTO farms (id, data, user) VALUES ("  + idEscaped +  ", ';;', " + userEscaped +  ") ON DUPLICATE KEY UPDATE user=IF(user='none'," + userEscaped +  ", user);", function (error, results, fields) {

      const embed = new MessageEmbed()
        .setColor(0x40ab5c)
        .setTitle("Linked ID to your Discord account successfully")
        .setDescription("");
      msg.channel.send(embed).then(sentmsg => {

        if (msg.channel.type != "dm") {
          setTimeout(() => msg.delete().catch(), 1);
          setTimeout(() => sentmsg.delete().catch(), minsTimeout * 60 * 1000);
        }
      });
    });

    connection.end();
}

//shows disclaimer when user runs command in #general
function tooPowerful(msg) {
  msg.reply("Oh no! This command is too powerful for this channel!\nPlease run it in <#838813418793336832> so we can keep this channel free of SPAM.");
}

const prefix = "!"
client.on('message', (msg) => {
  if (msg.content.startsWith(prefix)) {
    const commandBody = msg.content.slice(prefix.length); //something something stackoverflow
    const args = commandBody.split(' '); //arguments 
    const command = args.shift().toLowerCase();

    if (command === "clown") {
      msg.reply("Chris2 is a :clown:");
    }
    else if (command == "allenn") {
      msg.channel.send("<@96884333524041728> <:monkaStab:833539425405370408>")
    }
    //CHIA RELATED COMMAND
    else if (command === "chia" && args.length == 0) {
      runCommand("../server/chiabot_server.exe " + msg.author.id, msg, true);
    }
    else if (command === "chia" && msg.author.id == "829055244499419178" && args.length == 1) {
      runCommand("../server/chiabot_server.exe " + args[0], msg, true);
    }
    else if (command === "chia" && args.length == 1 && args[0] == "full") {
      if (msg.channel.id == "829057822213931062") {
        tooPowerful(msg);
      }
      else {
        runCommand("../server/chiabot_server.exe " + msg.author.id + " full", msg, true);
      }
    }
    else if (command === "chia" && args.length == 1 && args[0] == "workers") {
      if (msg.channel.id == "829057822213931062") {
        tooPowerful(msg);
      }
      else {
        runCommand("../server/chiabot_server.exe " + msg.author.id + " workers", msg, true);
      }
    }
    else if (command === "chia" && args.length == 1 && args[0] == "status") {
      runCommand("../server/chiabot_server.exe status", msg, true);
    }
    else if (command === "chia" && args.length == 1 && args[0] == "price") {
      runCommand("../server/chiabot_server.exe price", msg, true);
    }
    else if (command === "chia" && args.length == 1 && args[0] == "netspace") {
      runCommand("../server/chiabot_server.exe netspace", msg, true);
    }
    else if (command === 'chia' && args.length == 1 && args[0] == 'help') {

      const embed = new MessageEmbed()
        .setColor(0x40ab5c)
        .setTitle("Available commands")
        .setDescription(" `` !chia link [client-id] `` - links client to your discord account \n"
          + "`` !chia `` - displays your chia farm summary \n"
          + "`` !chia full `` - shows farm summary with additional statistics\n"
          + "`` !chia workers `` - show stats for each of your workers\n"
          + "`` !chia price `` - shows current XCH Exchange Rates\n"
          + "`` !chia netspace `` - shows current and past netspace\n"
          + "`` !chia api `` - link to your farm's data\n"
          + "`` !chia donate `` - shows developer's wallet address");

      msg.channel.send(embed);
    }
    // !chia api
    else if (command === 'chia' && args.length == 1 && args[0] == 'api') {
      msg.reply("https://chiabot.znc.sh/read.php?user=" + msg.author.id);
    }
    // !chia donate or !chia donation
    else if (command === 'chia' && args.length == 1 && (args[0] == 'donate' || args[0] == "donation")) {

      const embed = new MessageEmbed()
        .setColor(0x40ab5c)
        .setTitle("Donate to @joaquimguimaraes")
        .setURL("https://github.com/joaquimguimaraes/chiabot#donate")
        .setDescription(
          "XCH: xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9\nETH: 0x340281CbAd30702aF6dCA467e4f2524916bb9D61")
        .setImage("https://i.ibb.co/yhcqWWc/D42-ECA8-A-55-E2-499-B-BBF8-52176-B5190-A2.jpg");

      msg.channel.send(embed);
    }
    else if (command === "chia" && args[0] == "link" && args.length == 2) {
      var id = args[1];
      var user = msg.author.id;

      linkUser(id, user, msg);

    }

  }
});



