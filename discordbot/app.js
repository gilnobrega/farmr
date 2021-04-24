const Discord = require('discord.js');
const { Client, MessageEmbed } = require('discord.js');
const fetch = require('node-fetch');

require('dotenv').config();

const client = new Discord.Client();

const etherscanAPIKey = process.env.ETHERSCAN_TOKEN; //loads etherscan api key from environment variables file

client.on('ready', () => {
  console.log('Bot is ready');
});

client.login(process.env.BOT_TOKEN); //loads discord token from environment variables file

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
    output.forEach(worker => {

      var array = worker.split('--');

      var text = array[0];
      lastUpdated = "";

      if (array.length == 2) {
        lastUpdated = array[1];
      }

      const embed = new MessageEmbed()
        .setColor(0x40ab5c)
        .setDescription(text)
        .setFooter(lastUpdated);
      
        msg.channel.send(embed).then( sentmsg => {

          if (msg.channel.type != "dm")
          {
            setTimeout(() => msg.delete(), minsTimeout * 1 * 1000);
            setTimeout(() => sentmsg.delete(), minsTimeout * 1 * 1000);
          }
        });

    });

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

//takes a block number and outputs discord message with info about that block
function blockInfo(number, msg, luck, number2) {
  //ETHERSCAN BLOCK APIS, basically only used to get block reward
  const etherscanurlblock = 'https://api.etherscan.io/api?module=block&action=getblockreward&blockno=' + number + '&apikey=' + etherscanAPIKey;
  console.log(etherscanurlblock);
  fetch(etherscanurlblock)
    .then(function (u) { return u.json(); })
    .then(function (json) {
      block = json['result'];
      reward = block['blockReward'];
      mev = 0;
      prob = 0;
      //ETHERSCAN INTERNAL TRANSACTIONS APIS, BLOCK NUMBER IS A PARAMETER
      //filters mev transactions by block number
      if (number2 == undefined) number2 = number;

      const etherscanurlinttxs = 'https://api.etherscan.io/api?module=account&action=txlistinternal&address=0x7f101fe45e6649a6fb8f3f8b43ed03d353f2b90c&startblock=' + number + '&endblock=' + number2 + '&sort=asc&apikey=' + etherscanAPIKey;
      console.log(etherscanurlinttxs);
      fetch(etherscanurlinttxs)
        .then(function (v) { return v.json(); })
        .then(function (json2) {

          //bunch of mev transactions associated with that block number
          txs = json2['result'];
          //console.log(txs);

          //sums all of those mev transactions values into mevrewards
          for (i = 0; i < txs.length; i++) {
            mev = mev + txs[i]['value'];
          }

          //converts wei to eth and sums mev and reward
          mevEth = weiToEth(mev);
          rewardEth = weiToEth(reward);
          totalEth = weiToEth(+(mev) + +(reward));

          //if luck is defined adds a luck string to description
          luckstr = "";
          if (luck != undefined) {
            prob = (1 / Math.exp(1 / luck));
            if ((1 - prob) < prob) prob = 1 - prob;
            luckstr = "\n:four_leaf_clover: Luck/Effort: " + intToPerc(luck) + "% / " + intToPerc(1 / luck) + "%"
              + "\n:game_die: Probability: " + intToPerc(prob) + "%"; // " + intToPerc(1-prob) + "%";
          }
          //displays final message with info regarding that block
          const embed = new MessageEmbed()
            .setTitle('Block #' + number)
            .setColor(0xff0000)
            .setDescription(':money_mouth: Block Reward: ' + rewardEth + ' ETH\n' +
              ':money_with_wings: MEV: ' + mevEth + ' ETH\n' +
              ':moneybag: Total Reward: ' + totalEth + ' ETH'
              + luckstr); //luck string is optional whether its specified or not
          msg.channel.send(embed);

        });
    });


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
      runCommand("/usr/bin/dart ../server/chiabot_server.dart " + msg.author.id, msg, true);
    }
    else if (command === "chia" && msg.author.id == "829055244499419178" && args.length == 1) {
      runCommand("/usr/bin/dart ../server/chiabot_server.dart " + args[0], msg, true);
    }
    else if (command === "chia" && args.length == 1 && args[0] == "full") {
      runCommand("/usr/bin/dart ../server/chiabot_server.dart " + msg.author.id + " full", msg, true);
    }
    else if (command === "chia" && args.length == 1 && args[0] == "workers") {
      runCommand("/usr/bin/dart ../server/chiabot_server.dart " + msg.author.id + " workers", msg, true);
    }
    else if (command === 'chia' && args.length == 1 && args[0] == 'help') {

      const embed = new MessageEmbed()
        .setColor(0x00ff00)
        .setTitle("Available commands")
        .setDescription(" `` !chia link [client-id] `` - links client to your discord account \n"
          + "`` !chia `` - displays your chia farm summary \n"
          + "`` !chia full `` - shows farm summary with additional statistics\n"
          + "`` !chia workers `` - show stats for each of your workers\n"
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
        .setColor(0x00ff00)
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

      fetch("https://chiabot.znc.sh/assign.php?id=" + id + "&user=" + user);

      const embed = new MessageEmbed()
        .setColor(0x00ff00)
        .setTitle("Linked ID to your Discord account successfully")
        .setDescription("");
      msg.channel.send(embed);
    }

    //If no block number is specified then it uses flexpool api to find the latest block's number (even if it's unconfirmed)
    else if (command === "mev" && args.length == 0) {
      let blocks;
      //Flexpool API page, loads last 10 blocks
      const flexurl = 'https://flexpool.io/api/v1/pool/blocks?page=0';

      fetch(flexurl)
        .then(function (u) { return u.json(); })
        .then(function (json) {
          blocks = json['result']['data'];

          //loads last block
          lastblock = blocks[0];

          number = lastblock['number'];
          totalreward = lastblock['total_rewards'];
          mevreward = 0;
          luck = lastblock['luck'];

          console.log(number); //DELETE THIS LATER

          blockInfo(number, msg, luck);
        });

    }
    //IF a block number is specified next to the command then it searches etherscan directly for that block's info
    else if (command === "mev" && args.length == 1) {
      number = args[0];
      blockInfo(number, msg);
    }
    else if (command === "mev" && args.length == 2) {
      number = args[0];
      number2 = args[1];
      blockInfo(number, msg, undefined, number2);

    }

  }
});



