const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');

require('dotenv').config();

const client = new Discord.Client();

const etherscanAPIKey = process.env.ETHERSCAN_TOKEN; //loads etherscan api key from environment variables file

client.on('ready', () => {
  console.log('Bot is ready');
});

client.login(process.env.BOT_TOKEN_DEV); //loads discord token from environment variables file

const { exec } = require("child_process");

//executes shell command
function runCommand(command, msg, chia = false) {
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.log(`error: ${error.message}`);
      return;
    }
    if (stderr) {
      console.log(`stderr: ${stderr}`);
      return;
    }

    output = stdout;

    const embed = new MessageEmbed()
      .setColor(0x00ff00)
      .setDescription(output);
    msg.channel.send(embed);

    console.log(msg.author.id);

  });
}
//takes values in wei and outputs in eth, rounded up to 3 decimal places
function weiToEth(wei) {

  decimal = 2;

  return +(wei * Math.pow(10, -18)).toFixed(decimal); //+ in the beginning converts the string to int

}

function intToPerc(value) {
  decimal = 0;
  if (value < 0.05) decimal = 1;
  if (value < 0.01) decimal = 2;
  if (value < 0.001) decimal = 3;
  if (value < 0.0001) decimal = 4;

  console.log(value);
  return +(value * 100).toFixed(decimal);
}

const prefix = "!"
client.on('message', (msg) => {
  if (msg.content.startsWith(prefix)) {
    const commandBody = msg.content.slice(prefix.length); //something something stackoverflow
    const args = commandBody.split(' '); //arguments 
    const command = args.shift().toLowerCase();

    if (command =="chia2" && args.length == 0 && msg.author.id == "216180241138188288")
    {
        console.log(msg.author.id);
        const embed = new MessageEmbed()
        .setColor(0x00ff00)
        .setDescription("")
        .addFields(
          {name: 'Balance', value: 'XCH'},
          {name: 'Plots', value: '260', inline: true},
          {name: 'Last Plot', value: '01h00m', inline: true},
          {name: 'Space', value: '10 TB'}
        );
      msg.channel.send(embed);
    }

  }
});



