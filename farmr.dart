import 'dart:convert';
import 'dart:isolate';
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
import 'package:farmr_client/id.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';
import 'package:farmr_client/log/logitem.dart';

import 'package:farmr_client/environment_config.dart';

import 'package:farmr_client/stats.dart';
import 'package:farmr_client/server/netspace.dart';
import 'package:farmr_client/server/price.dart';
import 'package:uuid/uuid.dart';

import "package:console/console.dart";
import 'package:dart_console/dart_console.dart' as dartconsole;

final log = Logger('Client');

Duration reportIntervalDuration =
    Duration(minutes: 10); //10 minutes delay between updates

// '/home/user/.farmr' for package installs, '.' (project path) for the rest
String rootPath = "";

const String url = "https://farmr.net/send12.php";
const String urlBackup = "https://chiabot.znc.sh/send12.php";

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
  if (package) {
    String blockchainDir = rootPath + "blockchain";

    if (!io.Directory(blockchainDir).existsSync()) {
      io.Directory(blockchainDir).createSync();
    }

    //Links files from /etc/farmr/blockchain to user's .farmr/blockchain folder
    for (var path in defaultFolder.listSync()) {
      io.File file = io.File(path.path);
      io.File destFile = io.File(blockchainDir + "/" + basename(file.path));

      if (file.existsSync() && !destFile.existsSync()) {
        io.Link(destFile.path).createSync(file.path);
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

        if (blockchain.binaryName == "chia")
          reportIntervalDuration = blockchain.reportIntervalDuration;
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

Map<String, String> outputs = {};

main(List<String> args) async {
  clearLog();
  initLogger(); //initializes farmr logger

  //Kills command on ctrl c
  io.ProcessSignal.sigint.watch().listen((signal) {
    io.exit(0);
  });

  //launches client in onetime mode, where it runs one time and doesnt loop
  bool onetime = args.contains("onetime");
  //launches client in standalone mode where it doesnt send info to server
  bool standalone = args.contains("standalone") || args.contains("offline");

  bool packageMode = args.contains("package"); // alternative .deb config path

  //runs farmr in headless mode (doesnt ask for user input)
  bool headless = args.contains("headless");

  prepareRootPath(packageMode);
  createDirsAndportOldFiles(rootPath);

  ID id = ID(rootPath);
  await id.init(); //creates id.json or loads ids from id.json

  List<Blockchain> blockchains = readBlockchains(id, rootPath, args);

  for (Blockchain blockchain in blockchains) {
    //initializes ports and detects harvester/farmer mode
    await blockchain.initializePorts();

    //initializes blockchain class
    await blockchain.init(true);

    outputs.putIfAbsent(
        "${blockchain.currencySymbol.toUpperCase()} - View report",
        () => "Generating ${blockchain.currencySymbol} report");
    outputs.putIfAbsent(
        "${blockchain.currencySymbol.toUpperCase()} - View addresses",
        () => "Generating ${blockchain.currencySymbol} report");
  }

  //shows info with ids to link
  final String info = await id.info(blockchains);

  outputs.putIfAbsent("View list of IDs", () => info);
  outputs.putIfAbsent("Quit", () => "quit");

  int maxUsers = blockchains
      .map((e) => e.config.userNumber)
      .reduce((n1, n2) => Math.max(n1, n2));

  updateIDs(id, maxUsers);

  log.warning(info);

  final receivePort = ReceivePort();

  final mainIsolate = await Isolate.spawn(
    spawnBlokchains,
    [receivePort.sendPort, blockchains, onetime, standalone],
  );

  receivePort.listen((message) {
    var map = (message as Map<String, String>);

    for (var entry in map.entries)
      outputs.update(
          entry.key,
          (value) =>
              (entry.key == map.entries.first.key ? (value + "\n\n") : "") +
              entry.value);

    if ((message).entries.first.value.contains("not linked")) {
      receivePort.close();
      mainIsolate.kill();
      io.exit(1);
    }
  });

  //does not ask for user input in github workflow
  if (!blockchains.first.configPath.contains(".github/workflows") && !headless)
    reportSelector();
  else if (headless) log.warning("Running in headless mode");
}

bool firstTime = true;

late dartconsole.Console console;
Future<void> reportSelector() async {
  print("""\nfarmr sends a report every 10 minutes.
Do not close this window or these stats will not show up in farmr.net and farmrBot
""");

  try {
    //initializes consoles if its the first time this function is running
    if (firstTime) {
      console = dartconsole.Console();
      Console.init();
      firstTime = false;
    }

    var chooser = Chooser<String>(
      outputs.entries.map((entry) => entry.key).toList(),
      message: 'Select action number: ',
    );

    chooser.choose().then((value) {
      if (value != null) {
        //otherwise clears screen
        console.clearScreen();

        if (outputs[value] != "quit")
          print(outputs[value]);
        else
          io.exit(0);
      }

      reportSelector();
    });
    //catches error in case one of the console library crashes, e.g.: if requires user input
  } catch (error) {}
}

void timeoutIsolate(SendPort timeoutPort) {
  final int timeOutMins = reportIntervalDuration.inMinutes * 2;

  io.sleep(Duration(minutes: timeOutMins));

  timeoutPort.send("timeout");
}

//blockchain spawner
//evenly distributes blockchains within delay time
//e.g.: 3 blockchains over 10 mins -> 3.33 mins per blockchain
void spawnBlokchains(List<Object> arguments) async {
  SendPort sendPort = arguments[0] as SendPort;
  List<Blockchain> blockchains = arguments[1] as List<Blockchain>;
  bool onetime = arguments[2] as bool;
  bool standalone = arguments[3] as bool;

  initLogger(); //initializes logger

  int counter = 0;

  final int delayBetweenInMilliseconds =
      (reportIntervalDuration.inMilliseconds / blockchains.length).round();

  //log parser isolate
  for (Blockchain blockchain in blockchains) {
    //starts isolate for log parsing
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      startLogParsing,
      [receivePort.sendPort, blockchain, onetime],
    );

    receivePort.listen((message) {
      if (message is String) {
        log.warning(message);

        if (message.contains("stopped")) {
          receivePort.close();
          isolate.kill();
        }
      } else if (message is List<Object>) {
        blockchain.log.filters = message[0] as List<Filter>;
        blockchain.log.signagePoints = message[1] as List<SignagePoint>;
        blockchain.log.shortSyncs = message[2] as List<ShortSync>;
        blockchain.log.poolErrors = message[3] as List<LogItem>;
        blockchain.log.harvesterErrors = message[4] as List<LogItem>;

        blockchain.log.genSubSlots();
      }
    });
  }

  while (true) {
    clearLog(); //clears log

    counter++;

    log.info("Generating new report #$counter");

    for (int i = 0; i < blockchains.length; i++) {
      Blockchain blockchain = blockchains[i];

      //evenly distributes blockchains
      final int blockchainDelay =
          (counter > 1) ? i * delayBetweenInMilliseconds : 0;

      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        handleBlockchainReport,
        [
          receivePort.sendPort,
          blockchain,
          blockchains.length,
          onetime,
          standalone,
          blockchainDelay
        ],
      );

      void killMainIsolate() {
        receivePort.close();
        isolate.kill();
        if (standalone) io.exit(0);
      }

      receivePort.listen((message) {
        sendPort.send({
          "${blockchain.currencySymbol.toUpperCase()} - View report":
              (message as List<String>)[0],
          "${blockchain.currencySymbol.toUpperCase()} - View addresses": """
Farmer Reward Address: ${message[3]}
Pool Reward Address: ${message[4]}

Local Addresses:
${message[1]}

Cold Addresses:
${message[2]}

These addresses are NOT reported to farmr.net or farmrBot
""",
        });

        killMainIsolate();
      });

      //kills main isolate after 20 minutes
      final timeoutPort = ReceivePort();
      final timeOutIsolate =
          await Isolate.spawn(timeoutIsolate, timeoutPort.sendPort);

      timeoutPort.listen((message) {
        timeOutIsolate.kill();
        killMainIsolate();
      });
    }

    await Future.delayed(reportIntervalDuration);
    if (onetime) io.exit(0);
  }
}

void startLogParsing(List<Object> arguments) async {
  SendPort sendPort = arguments[0] as SendPort;
  Blockchain blockchain = arguments[1] as Blockchain;
  bool onetime = arguments[2] as bool;

  sendPort
      .send("${blockchain.currencySymbol.toUpperCase()}: started log parser");

  await Future.delayed(Duration(minutes: 1));
  await blockchain.log
      .initLogParsing(blockchain.config.parseLogs, onetime, sendPort);

  sendPort
      .send("${blockchain.currencySymbol.toUpperCase()}: stopped log parser");
}

//blockchain isolate
void handleBlockchainReport(List<Object> arguments) async {
  SendPort sendPort = arguments[0] as SendPort;
  Blockchain blockchain = arguments[1] as Blockchain;
  int blockchainsLength = arguments[2] as int;
  bool onetime = arguments[3] as bool;
  bool standalone = arguments[4] as bool;
  int blockchainDelay = arguments[5] as int;

  //kills isolate after 20 minutes
  Future.delayed(
      Duration(
          minutes: (!onetime) ? (reportIntervalDuration.inMinutes * 2) : 1),
      () {
    sendPort.send([
      "${blockchain.currencySymbol} report killed. Are ${blockchain.binaryName} services running?",
      "",
      "",
      "",
      ""
    ]);
  });

  clearLog(blockchain.fileExtension); //clears log
  initLogger(blockchain.fileExtension); //initializes logger

  // ClientType type = arguments[5] as ClientType;

  //sendPort.send(42 + number);

  String lastPlotID = "";
  String balance = "";
  String status = "";
  String copyJson = "";
  String name = "";
  String drives = "";
  String coldBalance = "";
  String output = "";
  String localAddresses = "";
  String coldAddresses = "";
  String farmerRewardAddress = "";
  String poolRewardAddress = "";

  //delays blockchain report by amount defined in isolate spawner
  await Future.delayed(Duration(milliseconds: blockchainDelay));

  //PARSES DATA
  // try {
  //loads cache every 10 minutes
  //loads config every 10 minutes
  await blockchain.init(false);
  //starts parsing logs every x seconds

  var client;

  //initializes client based on type detected by blockchain
  switch (blockchain.type) {
    case ClientType.Farmer:
      client = client = Farmer(
          rootPath: rootPath,
          blockchain: blockchain,
          version: EnvironmentConfig.version,
          type: blockchain.config.type);
      break;

    case ClientType.Harvester:
      client = Harvester(blockchain, EnvironmentConfig.version);
      break;

    case ClientType.HPool:
      client =
          HPool(blockchain: blockchain, version: EnvironmentConfig.version);
      break;
  }

  //hpool has a special config.yaml directory, as defined in farmr's config.json
  await client.init();

  //Throws exception in case no plots were found
  if (client.plots.length == 0)
    log.warning(
        "No plots have been found! Make sure your user has access to the folders where plots are stored.");

  //if plot notifications are off then it will default to 0
  lastPlotID =
      (blockchain.config.sendPlotNotifications) ? client.lastPlotID() : "0";

  //if hard drive notifications are disabled then it will default to 0
  drives = (blockchain.config.sendDriveNotifications)
      ? client.drives.length.toString()
      : "0";

  //sends notifications about cold wallet if that is enabled
  if (client is Farmer) {
    if (client.coldWallets.length > 0) {
      if (client.coldWalletAggregate.farmedBalance >= 0)
        coldBalance = client.coldWalletAggregate.farmedBalanceMajor
            .toStringAsFixed(2); //flax //LEGACY
      else if (client.coldWalletAggregate.grossBalance >= 0)
        coldBalance = client.coldWalletAggregate.grossBalanceMajor
            .toStringAsFixed(2); //chia // LEGACY
      else if (client.coldWalletAggregate.netBalance >= 0)
        coldBalance = client.coldWalletAggregate.netBalanceMajor
            .toStringAsFixed(2); //every other fork through posat.io
    }

    if (client.balance >= 0) balance = client.balance.toStringAsFixed(2);
  }

  for (String address in client.localAddresses)
    localAddresses += "\n    - $address";
  for (String address in client.coldAddresses)
    coldAddresses += "\n    - $address";
  farmerRewardAddress = client.farmerRewardAddress;
  poolRewardAddress = client.poolRewardAddress;

  status = client.status;

  if (blockchainsLength > 1)
    output += "\nStats for ${blockchain.binaryName} farm:";
  //shows stats in client
  output += Stats.showHarvester(
      client,
      0,
      0,
      //shows netspace is client is farmer or foxypoolOG since foxypoolOG uses same chia client and full node
      (client is Farmer) ? client.netSpace : NetSpace(),
      false,
      true,
      Rate(0, 0, 0),
      false);

  name = client.name;
  if (blockchainsLength > 1) name += " (${blockchain.currencySymbol})";

  //copies object to a json string
  copyJson = jsonEncode(client);
  // } catch (exception) {
//    log.severe("Oh no! Something went wrong.");
  //  log.severe(exception.toString());
  //  log.info("Config:\n${blockchain.cache}\n");
  //  log.info("Cache:\n${blockchain.cache}");
  //  if (onetime) io.exit(1);
  //}

  if (!standalone) {
    await Future.sync(() {
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

        if (blockchain.config.sendStatusNotifications)
          post.putIfAbsent("isFarming", () => isFarming);

        //Adds the following if sendPlotNotifications is enabled then it will send plotID
        if (blockchain.config.sendPlotNotifications)
          post.putIfAbsent("lastPlot", () => lastPlotID);

        //Adds the following if hard drive notifications are enabled then it will send the number of drives connected to pc
        if (blockchain.config.sendDriveNotifications)
          post.putIfAbsent("drives", () => drives);

        bool isFarmerLike = (blockchain.config.type == ClientType.Farmer);
        //If the client is a farmer and it is farming and sendBalanceNotifications is enabled then it will send balance
        if (isFarmerLike &&
            blockchain.config.sendBalanceNotifications &&
            status == "Farming" &&
            balance != "") post.putIfAbsent("balance", () => balance);
        //if cold balance has been read and cold balance notifications are enabled then it will send coldBalance to server
        if (blockchain.config.sendColdWalletNotifications && coldBalance != "")
          post.putIfAbsent("coldBalance", () => coldBalance);

        String type = isFarmerLike ? "farmer" : "harvester";

        for (String id in blockchain.id.ids) {
          //Appends blockchain symbol to id
          post.putIfAbsent("id", () => id + blockchain.fileExtension);
          post.update("id", (value) => id + blockchain.fileExtension);

          sendReport(
              id,
              post,
              blockchain,
              type,
              sendPort,
              output,
              localAddresses,
              coldAddresses,
              farmerRewardAddress,
              poolRewardAddress);
        }

        log.info("url:$url");
        log.info("data sent:\n$sendJson");
      } catch (exception) {
        log.severe("Oh no, failed to connect to server!");
        log.severe(exception.toString());
      }
    }).catchError((error) {
      log.info(error);
    });
  }
}

Future<void> sendReport(
    String id,
    Object? post,
    Blockchain blockchain,
    String type,
    SendPort sendPort,
    String previousOutput,
    String localAddresses,
    String coldAddresses,
    String farmerRewardAddress,
    String poolRewardAddress,
    [bool retry = true]) async {
  String contents = "";
  //sends report to farmr.net
  await http.post(Uri.parse(url), body: post).then((_) {
    contents = _.body;
    String idText = (blockchain.id.ids.length == 1)
        ? ''
        : "for id " + id + blockchain.fileExtension;
    String timestamp = DateFormat.Hms().format(DateTime.now());
    previousOutput +=
        "\n$timestamp - Sent ${blockchain.binaryName} $type report to server $idText\nResending it in ${reportIntervalDuration.inMinutes} minutes";

    checkIfLinked(
        contents,
        previousOutput,
        sendPort,
        id + blockchain.fileExtension,
        localAddresses,
        coldAddresses,
        farmerRewardAddress,
        poolRewardAddress);
  }).catchError((error) {
    previousOutput +=
        "Server timeout, could not access farmr.net.\nRetrying with backup domain.";
    log.info(error.toString());

    //sends report to chiabot.znc.sh (legacy/backup domain)
    if (retry)
      sendReport(
          id,
          post,
          blockchain,
          type,
          sendPort,
          previousOutput,
          localAddresses,
          coldAddresses,
          farmerRewardAddress,
          poolRewardAddress,
          false);
    else
      sendPort.send([
        previousOutput +=
            "\nServer timeout, could not access farmr.net (or the backup domain chiabot.znc.sh)",
        localAddresses,
        coldAddresses,
        farmerRewardAddress,
        poolRewardAddress
      ]);
  });
}

Future<void> checkIfLinked(
    String response,
    String previousOutput,
    SendPort sendPort,
    String id,
    String localAddresses,
    String coldAddresses,
    String farmerRewardAddress,
    String poolRewardAddress) async {
  if (response.trim().contains("Not linked")) {
    final errorString = """\n\nID $id is not linked to an account.
Link it in farmr.net or through farmrbot and then start this program again
Press enter to quit""";
    print(errorString);
    sendPort.send([
      "not linked",
      localAddresses,
      coldAddresses,
      farmerRewardAddress,
      poolRewardAddress
    ]);

    Future.delayed(Duration(minutes: 10)).then((value) {
      io.exit(1);
    });

    io.stdin.readByteSync();
    io.exit(1);
  } else
    sendPort.send([
      previousOutput,
      localAddresses,
      coldAddresses,
      farmerRewardAddress,
      poolRewardAddress
    ]);
}

void clearLog([String blockchainExtension = ""]) {
  //logging on windows is disabled
  if (!io.Platform.isWindows) {
    try {
      io.File logFile = io.File(rootPath + "log$blockchainExtension.txt");

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

void initLogger([String blockchainExtension = ""]) {
  //TODO fix logging on windows

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
        io.File logFile = io.File(rootPath + "log$blockchainExtension.txt");

        logFile.writeAsStringSync(
            '\n${record.time} ${record.loggerName}: ' + output,
            mode: io.FileMode.writeOnlyAppend);
      } catch (e) {}
    }
  });
}
