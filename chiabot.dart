import 'dart:convert';
import 'dart:io' as io;
import 'dart:core';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'lib/farmer.dart';
import 'lib/harvester.dart';
import 'lib/config.dart';
import 'lib/cache.dart';
import 'lib/debug.dart';

final log = Logger('Client');

final Duration delay = Duration(minutes: 10); //10 minutes delay between updates

//Sets config file path according to platform
String chiaConfigPath = (io.Platform.isLinux)
    ? io.Platform.environment['HOME'] + "/.chia/mainnet/config/"
    : (io.Platform.isWindows)
        ? io.Platform.environment['UserProfile'] + "\\.chia\\mainnet\\config\\"
        : "";

//Sets config file path according to platform
String chiaDebugPath = (io.Platform.isLinux)
    ? io.Platform.environment['HOME'] + "/.chia/mainnet/log/"
    : (io.Platform.isWindows)
        ? io.Platform.environment['UserProfile'] + "\\.chia\\mainnet\\log\\"
        : "";

main(List<String> args) async {
  initLogger(); //initializes logger

  //Kills command on ctrl c
  io.ProcessSignal.sigint.watch().listen((signal) {
    io.exit(0);
  });

  Cache cache = new Cache(chiaConfigPath);
  cache.init();

  //Initializes config, either creates a new one or loads a config file
  Config config = new Config(cache, chiaConfigPath,
      (args.length == 1 && (args[0] == "harvester" || args[0] == '-h'))); //checks if is harvester

  await config.init();

  while (true) {
    String lastPlotID = "";
    String balance = "";
    String status = "";
    String copyJson = "";

    //PARSES DATA
    try {
      log.info("Generating new report");

      cache.init(config.parseLogs);
      Log chiaLog = new Log(chiaDebugPath, cache, config.parseLogs);

      var client = (config.type == ClientType.Farmer)
          ? new Farmer(config, chiaLog)
          : new Harvester(config, chiaLog);
      await client.init(chiaConfigPath);

      //Throws exception in case no plots were found
      if (client.plots.length == 0)
        log.warning(
            "No plots have been found! Make sure your user has access to the folders where plots are stored.");

      //if plot notifications are off then it will default to 0
      lastPlotID = (config.sendPlotNotifications) ? client.lastPlotID() : "0";

      if (client is Farmer) {
        balance = client.balance.toString();
        status = client.status;
      }

      //copies object to a json string
      copyJson = jsonEncode(client);
    } catch (exception) {
      log.severe("Oh no! Something went wrong.");
      log.severe(exception.toString());
      log.info("Config:\n${config}\n");
      log.info("Cache:\n${cache}");
    }

    //SENDS DATA TO SERVER
    try {
      var copy = (config.type == ClientType.Farmer)
          ? Farmer.fromJson("[" + copyJson + "]")
          : Harvester.fromJson("[" + copyJson + "]");

      //clones farm so it can clear ids before sending them to server
      copy.clearIDs();

      //String that's actually sent to server
      String sendJson = jsonEncode(copy);

      String notifyOffline = (config.sendOfflineNotifications) ? '1' : '0';

      String url = "https://chiabot.znc.sh/send.php?id=" +
          config.cache.id +
          "&notifyOffline=" +
          notifyOffline;

      //Adds the following if sendPlotNotifications is enabled then it will send plotID
      if (config.sendPlotNotifications) url += "&lastPlot=" + lastPlotID;

      //If the client is a farmer and it is farming and sendBalanceNotifications is enabled then it will send balance
      if (config.type == ClientType.Farmer &&
          config.sendBalanceNotifications &&
          status == "Farming") url += "&balance=" + Uri.encodeComponent(balance.toString());

      http.post(url, body: {"data": sendJson}).catchError(() {
        log.warning("Server timeout.");
      });

      String type = (config.type == ClientType.Farmer) ? "farmer" : "harvester";

      log.warning("Sent " +
          type +
          " report to server.\nRetrying in " +
          delay.inMinutes.toString() +
          " minutes");
      log.info("url:${url}");
      log.info("data sent:\n${sendJson}");

      if (io.Platform.isWindows) print("Do NOT close this window.");

      clearLog(); //clears log
    } catch (exception) {
      log.severe("Oh no, failed to connect to server!");
      log.severe(exception.toString());
    }

    await Future.delayed(delay);
  }
}

final io.File logFile = io.File("log.txt");

void clearLog() {
  try {
    //Deletes log file if it already exists
    if (logFile.existsSync()) {
      logFile.deleteSync();
    }

    //Creates log file
    if (io.Platform.isWindows)
      logFile.create().catchError( () {});
    else if (io.Platform.isLinux) logFile.createSync();
  } catch (e) {
    log.info("Failed to delete/create log.txt.\n${e}");
  }
}

void initLogger() {
  clearLog();

  //Initializes logger
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    String output = '${record.message}';
    if (record.level.value >= Level.WARNING.value)
      print(output); //prints output if level is warning/error

    //otherwise logs stuff to log file
    //2021-05-02 03:02:26.548953 Client: Sent farmer report to server.
    try {
      logFile.writeAsStringSync('\n${record.time} ${record.loggerName}: ' + output,
          mode: io.FileMode.append);
    } catch (e) {}
  });
}
