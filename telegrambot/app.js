const TelegramBot = require('node-telegram-bot-api');
require('dotenv').config();
const { exec } = require("child_process");

// replace the value below with the Telegram token you receive from @BotFather
const token = process.env.TOKEN

// Create a bot that uses 'polling' to fetch new updates
const bot = new TelegramBot(token, { polling: true });


// Matches "/echo [whatever]"
bot.onText(/!chia (.+)/, (msg, match) => {
    // 'msg' is the received Message from Telegram
    // 'match' is the result of executing the regexp above on the text content
    // of the message
    const userID = '216180241138188288'; //msg.from.username;
    const chatId = msg.chat.id;
    const args = match[1].split(' '); // the captured "whatever"
    
    if (args.length == 0) {
        runCommand("../server/farmr_server.exe " + userID, chatId);
    }
    else if (args.length == 1 && args[0] == "full") {
        runCommand("../server/farmr_server.exe " + userID + " full",chatId);
    }
    else if (args.length == 1 && args[0] == "workers") {
        runCommand("../server/farmr_server.exe " + userID + " workers",chatId);
    }
    else if (args.length == 1 && args[0] == "status") {
        runCommand("../server/farmr_server.exe status", chatId);
    }
    else if (args.length == 1 && args[0] == "price") {
        runCommand("../server/farmr_server.exe price", chatId);
    }

});

//executes shell command
function runCommand(command, chatID) {
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

            let parse_mode = 'Markdown';

            bot.sendMessage(chatID, text, /*{ parse_mode }*/);

        });

    });
}
