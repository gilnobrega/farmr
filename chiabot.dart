import 'dart:convert';
import 'package:universal_io/io.dart' as io;
import 'dart:core';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'package:chiabot/farmer.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/config.dart';
import 'package:chiabot/cache.dart';
import 'package:chiabot/debug.dart';
import 'package:chiabot/hpool.dart';

import 'server/chiabot_server.dart' as Stats;
import 'package:chiabot/server/netspace.dart';
import 'package:chiabot/server/price.dart';

final log = Logger('Client');

final String version = '1.3.0';

final Duration delay = Duration(minutes: 10); //10 minutes delay between updates

//test mode for github releases
String chiaConfigPath = (io.File(".github/workflows/config.yaml").existsSync())
    ? ".github/workflows"
//Sets config file path according to platform
    : (io.Platform.isLinux || io.Platform.isMacOS)
        ? io.Platform.environment['HOME']! + "/.chia/mainnet/config"
        : (io.Platform.isWindows)
            ? io.Platform.environment['UserProfile']! +
                "\\.chia\\mainnet\\config"
            : "";

//Sets config file path according to platform
String chiaDebugPath = (io.Platform.isLinux || io.Platform.isMacOS)
    ? io.Platform.environment['HOME']! + "/.chia/mainnet/log/"
    : (io.Platform.isWindows)
        ? io.Platform.environment['UserProfile']! + "\\.chia\\mainnet\\log\\"
        : "";

main(List<String> args) async {
  initLogger(); //initializes logger

  //Kills command on ctrl c
  io.ProcessSignal.sigint.watch().listen((signal) {
    io.exit(0);
  });

  String type = '';

  //launches client in onetime mode, where it runs one time and doesnt loop
  bool onetime = args.contains("onetime");
  //launches client in standalone mode where it doesnt send info to server
  bool standalone =
      onetime || args.contains("standalone") || args.contains("offline");

  Cache cache = new Cache(chiaConfigPath);
  cache.init();

  //Initializes config, either creates a new one or loads a config file
  Config config = new Config(cache, chiaConfigPath, args.contains("harvester"),
      args.contains("hpool")); //checks if is harvester (or hpool mode)

  await config.init();

  int counter = 1;

  while (!onetime || counter == 1) {
    String lastPlotID = "";
    String balance = "";
    String status = "";
    String copyJson = "";
    String name = "";
    String drives = "";

    //PARSES DATA
    try {
      clearLog(); //clears log

      log.info("Generating new report #$counter");

      cache.init();
      Log chiaLog = new Log(chiaDebugPath, cache, config.parseLogs);

      var client = (config.type == ClientType.Farmer)
          ? Farmer(config: config, log: chiaLog, version: version)
          : (config.type == ClientType.HPool)
              ? HPool(config: config, log: chiaLog, version: version)
              : Harvester(config, chiaLog, version);
      //hpool has a special config.yaml directory, as defined in chiabot's config.json
      await client.init((config.type == ClientType.HPool)
          ? config.hpoolConfigPath
          : chiaConfigPath);

      //Throws exception in case no plots were found
      if (client.plots.length == 0)
        log.warning(
            "No plots have been found! Make sure your user has access to the folders where plots are stored.");

      //if plot notifications are off then it will default to 0
      lastPlotID = (config.sendPlotNotifications) ? client.lastPlotID() : "0";

      //if hard drive notifications are disabled then it will default to 0
      drives =
          (config.sendDriveNotifications) ? client.drivesCount.toString() : "0";

      if (client is Farmer) {
        balance = client.balance.toString();
        status = client.status;
      }

      //shows stats in client
      Stats.showHarvester(
          client,
          0,
          0,
          (client is Farmer) ? client.netSpace : NetSpace(),
          false,
          true,
          Rate(0, 0, 0),
          false);

      name = client.name;

      //copies object to a json string
      copyJson = jsonEncode(client);
    } catch (exception) {
      log.severe("Oh no! Something went wrong.");
      log.severe(exception.toString());
      log.info("Config:\n$config\n");
      log.info("Cache:\n$cache");
      if (onetime) io.exit(1);
    }

    if (!standalone) {
      //SENDS DATA TO SERVER
      try {
        //clones farm so it can clear ids before sending them to server
        //copy.clearIDs();
        //deprecated

        //String that's actually sent to server
        String sendJson = copyJson;

        String notifyOffline = (config.sendOfflineNotifications)
            ? '1'
            : '0'; //whether user wants to be notified when rig goes offline
        String isFarming = (status == "Farming" || status == "Harvesting")
            ? '1' //1 means is farming/harvesting
            : '0';

        String publicAPI = (config.publicAPI)
            ? '1' //1 means client data can be seen from public api
            : '0';

        Map<String, String> post = {
          "data": sendJson,
          "notifyOffline": notifyOffline,
          "name": name,
          "publicAPI": publicAPI
        };

        String url = "https://chiabot.znc.sh/send6.php";

        if (config.type == ClientType.Farmer && config.sendStatusNotifications)
          post.putIfAbsent("isFarming", () => isFarming);

        //Adds the following if sendPlotNotifications is enabled then it will send plotID
        if (config.sendPlotNotifications)
          post.putIfAbsent("lastPlot", () => lastPlotID);

        //Adds the following if hard drive notifications are enabled then it will send the number of drives connected to pc
        if (config.sendDriveNotifications)
          post.putIfAbsent("drives", () => drives);

        //If the client is a farmer and it is farming and sendBalanceNotifications is enabled then it will send balance
        if (config.type == ClientType.Farmer &&
            config.sendBalanceNotifications &&
            status == "Farming") post.putIfAbsent("balance", () => balance);

        type = (config.type == ClientType.Farmer) ? "farmer" : "harvester";

        for (String id in cache.ids) {
          post.putIfAbsent("id", () => id);
          post.update("id", (value) => id);

          http.post(Uri.parse(url), body: post).catchError((error) {
            log.warning("Server timeout.");
            log.info(error.toString());
          }).whenComplete(() {
            String idText = (cache.ids.length == 1) ? '' : "for id " + id;
            String timestamp = DateFormat.Hms().format(DateTime.now());
            log.warning(
                "\n$timestamp - Sent $type report to server $idText\nRetrying in ${delay.inMinutes} minutes");
          });
        }

        log.info("url:$url");
        log.info("data sent:\n$sendJson");

        if (io.Platform.isWindows) print("Do NOT close this window.");
      } catch (exception) {
        log.severe("Oh no, failed to connect to server!");
        log.severe(exception.toString());
      }
    }

    counter += 1;

    if (!onetime) await Future.delayed(delay);
  }

  io.exit(0);
}

void clearLog() {
  //logging on windows is disabled
  if (!io.Platform.isWindows) {
    try {
      io.File logFile = io.File("log.txt");

      //Deletes log file if it already exists
      if (logFile.existsSync()) {
        logFile.deleteSync();
      }
      //creates log.txt
      logFile.createSync();
    } catch (err) {
      log.info("Failed to delete/create log.txt.\n$err");
    }
  }
}

void initLogger() {
  //logging on windows is disabled. Temporary, needs fixing
  clearLog();

  //Initializes logger
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    String output = '${record.message}';
    if (record.level.value >= Level.WARNING.value)
      print(output); //prints output if level is warning/error

    //otherwise logs stuff to log file
    //2021-05-02 03:02:26.548953 Client: Sent farmer report to server.
    //logs on windows is disabled
    if (!io.Platform.isWindows) {
      try {
        io.File logFile = io.File("log.txt");

        logFile.writeAsStringSync(
            '\n${record.time} ${record.loggerName}: ' + output,
            mode: io.FileMode.writeOnlyAppend);
      } catch (e) {}
    }
  });
}
