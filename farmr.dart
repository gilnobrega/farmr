import 'dart:convert';
import 'package:path/path.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:core';
import 'dart:math' as Math;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/hpool/hpool.dart';
import 'package:farmr_client/foxypool/foxypoolog.dart';
import 'package:farmr_client/id.dart';

import 'package:farmr_client/environment_config.dart';

import 'package:farmr_client/stats.dart';
import 'package:farmr_client/server/netspace.dart';
import 'package:farmr_client/server/price.dart';
import 'package:uuid/uuid.dart';

final log = Logger('Client');

final Duration delay = Duration(minutes: 10); //10 minutes delay between updates

// '/home/user/.farmr' for package installs, '.' (project path) for the rest
late String rootPath;

//prepares rootPath
prepareRootPath(bool package) {
  rootPath = (io.Platform.isLinux && package)
      ? io.Platform.environment['HOME']! + "/.farmr/"
      : "";

  //Creates /home/user/.farmr folder if that doesnt exist
  if (package && !io.Directory(rootPath).existsSync()) {
    //creates .farmr
    io.Directory(rootPath).createSync();
  }

  io.Directory defaultFolder = io.Directory("/etc/farmr/blockchain");

  //copies blockchain templates to .farmr
  if (package && defaultFolder.existsSync()) {
    String blockchainDir = rootPath + "blockchain/";

    if (!io.Directory(blockchainDir).existsSync()) {
      io.Directory(blockchainDir).createSync();
      for (var path in defaultFolder.listSync()) {
        io.File file = io.File(path.path);

        if (file.existsSync()) {
          file.copySync(blockchainDir + basename(file.path));
        }
      }
    }
  }
}

createDirsAndportOldFiles(String rootPath) {
  io.Directory configDir = io.Directory(rootPath + "config");
  io.File configFile = io.File(rootPath + "config.json");

  if (!configDir.existsSync()) {
    configDir.createSync();
    if (configFile.existsSync()) {
      configFile.copySync(rootPath + "config/config-xch.json");
      configFile.deleteSync();
    }
  }

  io.Directory cacheDir = io.Directory(rootPath + "cache");
  List<io.File> cacheFiles = [
    io.File(rootPath + ".chiabot_cache.json"),
    io.File(rootPath + ".farmr_cache.json")
  ];

  if (!cacheDir.existsSync()) {
    cacheDir.createSync();
    for (io.File cacheFile in cacheFiles) {
      if (cacheFile.existsSync()) {
        cacheFile.copySync(rootPath + "cache/cache-xch.json");
        cacheFile.deleteSync();
      }
    }
  }
}

List<Blockchain> readBlockchains(ID id, String rootPath, List<String> args) {
  List<Blockchain> blockchains = [];

  io.Directory blockchainDir = io.Directory(rootPath + "blockchain");

  if (blockchainDir.existsSync()) {
    for (var file in blockchainDir.listSync()) {
      //only loads files ending in .json and not .json.template
      if (file.path.endsWith(".json")) {
        Blockchain blockchain = Blockchain(id, rootPath, args,
            jsonDecode(io.File(file.path).readAsStringSync()));
        blockchains.add(blockchain);
      }
    }
  }

  return blockchains;
}

void updateIDs(ID id, int userNumber) {
  /** Generate Discord Id's */
  if (id.ids.length != userNumber) {
    if (userNumber > id.ids.length) {
      // More Id's (add)
      int newIds = userNumber - id.ids.length;
      for (int i = 0; i < newIds; i++) id.ids.add(Uuid().v4());
    } else if (userNumber < id.ids.length) {
      // Less Id's (fresh list)
      id.ids = [];
      for (int i = 0; i < userNumber; i++) id.ids.add(Uuid().v4());
    }
    id.save();
  }
}

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

  bool packageMode = args.contains("package"); // alternative .deb config path

  prepareRootPath(packageMode);
  createDirsAndportOldFiles(rootPath);

  ID id = ID(rootPath);
  await id.init(); //creates id.json or loads ids from id.json

  List<Blockchain> blockchains = readBlockchains(id, rootPath, args);

  for (Blockchain blockchain in blockchains) await blockchain.init();

  int maxUsers = blockchains
      .map((e) => e.config.userNumber)
      .reduce((n1, n2) => Math.max(n1, n2));

  updateIDs(id, maxUsers);

  //shows info with ids to link
  id.info(blockchains);

  int counter = 0;

  while (true) {
    counter += 1;
    log.info("Generating new report #$counter");

    for (Blockchain blockchain in blockchains) {
      String lastPlotID = "";
      String balance = "";
      String status = "";
      String copyJson = "";
      String name = "";
      String drives = "";
      String coldBalance = "";

      //PARSES DATA
      try {
        clearLog(); //clears log

        // TODO: Split this apart so duplicate isn't necessary
        await blockchain.cache.init();
        blockchain.logUpdate();

        var client;

        //if its xch
        if (blockchain.currencySymbol == "xch") {
          if (blockchain.config.type == ClientType.Farmer)
            client = Farmer(
                blockchain: blockchain, version: EnvironmentConfig.version);
          else if (blockchain.config.type == ClientType.HPool)
            client = HPool(
                blockchain: blockchain, version: EnvironmentConfig.version);
          else if (blockchain.config.type == ClientType.FoxyPoolOG)
            client = FoxyPoolOG(
                blockchain: blockchain, version: EnvironmentConfig.version);
          else
            client = Harvester(blockchain, EnvironmentConfig.version);
        }
        //if its not xch then it wont start foxypool or hpool mode
        //will default to farmer mode unless harvester domain is specific in addition to hpool
        else {
          if (args.contains("harvester"))
            client = Harvester(blockchain, EnvironmentConfig.version);
          else
            client = Farmer(
                blockchain: blockchain, version: EnvironmentConfig.version);
        }

        //hpool has a special config.yaml directory, as defined in farmr's config.json
        await client.init();

        //Throws exception in case no plots were found
        if (client.plots.length == 0)
          log.warning(
              "No plots have been found! Make sure your user has access to the folders where plots are stored.");

        //if plot notifications are off then it will default to 0
        lastPlotID = (blockchain.config.sendPlotNotifications)
            ? client.lastPlotID()
            : "0";

        //if hard drive notifications are disabled then it will default to 0
        drives = (blockchain.config.sendDriveNotifications)
            ? client.drivesCount.toString()
            : "0";

        //sends notifications about cold wallet if that is enabled
        if (client is Farmer) {
          if (client.coldWallet.grossBalance >= 0)
            coldBalance = client.coldWallet.grossBalance.toString();

          if (client.balance >= 0) balance = client.balance.toString();
        }

        status = client.status;

        if (blockchains.length > 1)
          print("\nStats for ${blockchain.binaryName} farm:");
        //shows stats in client
        print(Stats.showHarvester(
            client,
            0,
            0,
            //shows netspace is client is farmer or foxypoolOG since foxypoolOG uses same chia client and full node
            (client is Farmer || client is FoxyPoolOG)
                ? (client as Farmer).netSpace
                : NetSpace(),
            false,
            true,
            Rate(0, 0, 0),
            false));

        name = client.name;
        if (blockchains.length > 1) name += " (${blockchain.currencySymbol})";

        //copies object to a json string
        copyJson = jsonEncode(client);
      } catch (exception) {
        log.severe("Oh no! Something went wrong.");
        log.severe(exception.toString());
        log.info("Config:\n${blockchain.cache}\n");
        log.info("Cache:\n${blockchain.cache}");
        if (onetime) io.exit(1);
      }

      if (!standalone) {
        Future.sync(() {
          //SENDS DATA TO SERVER
          try {
            //clones farm so it can clear ids before sending them to server
            //copy.clearIDs();
            //deprecated

            //String that's actually sent to server
            String sendJson = copyJson;

            String notifyOffline = (blockchain.config.sendOfflineNotifications)
                ? '1'
                : '0'; //whether user wants to be notified when rig goes offline
            String isFarming = (status == "Farming" || status == "Harvesting")
                ? '1' //1 means is farming/harvesting
                : '0';

            String publicAPI = (blockchain.config.publicAPI)
                ? '1' //1 means client data can be seen from public api
                : '0';

            Map<String, String> post = {
              "data": sendJson,
              "notifyOffline": notifyOffline,
              "name": name,
              "publicAPI": publicAPI
            };

            const String url = "https://farmr.net/send8.php";
            const String urlBackup = "https://chiabot.znc.sh/send8.php";

            if (blockchain.config.sendStatusNotifications)
              post.putIfAbsent("isFarming", () => isFarming);

            //Adds the following if sendPlotNotifications is enabled then it will send plotID
            if (blockchain.config.sendPlotNotifications)
              post.putIfAbsent("lastPlot", () => lastPlotID);

            //Adds the following if hard drive notifications are enabled then it will send the number of drives connected to pc
            if (blockchain.config.sendDriveNotifications)
              post.putIfAbsent("drives", () => drives);

            //If the client is a farmer and it is farming and sendBalanceNotifications is enabled then it will send balance
            if (blockchain.config.type == ClientType.Farmer &&
                blockchain.config.sendBalanceNotifications &&
                status == "Farming") post.putIfAbsent("balance", () => balance);
            //if cold balance has been read and cold balance notifications are enabled then it will send coldBalance to server
            if (blockchain.config.type == ClientType.Farmer &&
                blockchain.config.sendColdWalletBalanceNotifications &&
                coldBalance != "")
              post.putIfAbsent("coldBalance", () => coldBalance);

            type = (blockchain.config.type == ClientType.Farmer)
                ? "farmer"
                : "harvester";

            for (String id in blockchain.id.ids) {
              //Appends blockchain symbol to id
              post.putIfAbsent("id", () => id + blockchain.fileExtension);
              post.update("id", (value) => id + blockchain.fileExtension);

              http.post(Uri.parse(url), body: post).then((_) {
                String idText = (blockchain.id.ids.length == 1)
                    ? ''
                    : "for id " + id + blockchain.fileExtension;
                String timestamp = DateFormat.Hms().format(DateTime.now());
                log.warning(
                    "\n$timestamp - Sent ${blockchain.binaryName} $type report to server $idText\nResending it in ${delay.inMinutes} minutes");
              }).catchError((error) {
                log.warning(
                    "Server timeout, could not access farmr.net.\nRetrying with backup domain.");
                log.info(error.toString());

                http.post(Uri.parse(urlBackup), body: post).then((_) {
                  String idText = (blockchain.id.ids.length == 1)
                      ? ''
                      : "for id " + id + blockchain.fileExtension;
                  String timestamp = DateFormat.Hms().format(DateTime.now());
                  log.warning(
                      "\n$timestamp - Sent ${blockchain.binaryName} $type report to server $idText\nResending it in ${delay.inMinutes} minutes");
                }).catchError((error) {
                  log.warning(
                      "Server timeout. Could not send report to server!");

                  log.info(error.toString());
                });
              });
            }

            log.info("url:$url");
            log.info("data sent:\n$sendJson");

            if (io.Platform.isWindows) print("Do NOT close this window.");
          } catch (exception) {
            log.severe("Oh no, failed to connect to server!");
            log.severe(exception.toString());
          }
        }).catchError((error) {
          log.info(error);
        });
      }
    }

    if (onetime) io.exit(0);

    //shows info with ids to link
    id.info(blockchains);

    await Future.delayed(delay);
  }
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
