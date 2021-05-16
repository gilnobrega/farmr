import 'dart:core';

import 'package:mysql1/mysql1.dart' as mysql;
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:chiabot/farmer.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/stats.dart';
import 'package:chiabot/server/price.dart';
import 'package:chiabot/server/netspace.dart';

Future<void> main(List<String> args) async {
  dotenv.load();

  //prints chiabot status
  if (args[0] == "status") {
    await _getUsers();
  } else if (args[0] == "price") {
    Price price = await _getPrice();

    final List<String> currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
    final List<String> cryptos = ['BTC', 'ETH'];

    for (String currency in currencies)
      print("XCH/${currency}: **${price.rates[currency].toStringAsFixed(2)}**");

    print("");

    for (String currency in cryptos)
      print("XCH/${currency}: **${price.rates[currency].toStringAsPrecision(3)}**");

    Duration difference =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(price.timestamp));

    String coinMarketCap = ' - coinmarketcap.com';

    if (difference.inMinutes > 0)
      print("-- last updated ${difference.inMinutes} minutes ago" + coinMarketCap);
    else
      print("-- last updated ${difference.inSeconds} seconds ago" + coinMarketCap);
  } else if (args[0] == "netspace") {
    NetSpace netspace = NetSpace();
    await netspace.init();

    var entries = netspace.pastSizes.entries.toList();
    if (entries.length > 0) entries.removeLast();
    entries.sort((entry1, entry2) => int.parse(entry2.key).compareTo(int.parse(entry1.key)));

    print("Netspace: **${netspace.humanReadableSize}** ${netspace.dayDifference}\n");

    int until = 6;
    for (int i = 0; i < until && i < entries.length; i++) {
      var pastSize = entries[i];

      DateTime pastSizeDate = DateTime.fromMillisecondsSinceEpoch(int.parse(pastSize.key));

      String date = DateFormat('MMM dd').format(pastSizeDate);
      String size = NetSpace.generateHumanReadableSize(pastSize.value);

      print("${date}: ${size}");
    }

    Duration difference =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(netspace.timestamp));

    if (difference.inMinutes > 0)
      print("-- last updated ${difference.inMinutes} minutes ago - chianetspace.com");
    else
      print("-- last updated ${difference.inSeconds} seconds ago - chianetspace.com");
  } else {
    //Discord User ID
    String userID = args[0];

    Price price;

    List<Harvester> harvesters;

    int farmersCount = 0;
    int harvestersCount = 0;

    NetSpace netspace = NetSpace();

    try {
      //Gets user data and Price in parallel, since both are parsed from web
      final async1 = _getUserData(userID);
      final async2 = _getPrice();
      final async3 = netspace.init();

      harvesters = await async1;
      price = await async2;
      await async3;
    } catch (e) {
      print("Failed to connect to server.");
    }

    try {
      if (harvesters.length == 0) throw new Exception("No Harvesters found.");

      //Sorts harvesters by newest
      harvesters.sort((client2, client1) => (client1.lastUpdated.millisecondsSinceEpoch
          .compareTo(client2.lastUpdated.millisecondsSinceEpoch)));

      Farmer farm =
          harvesters.where((client) => client is Farmer).first; //Selects newest farm as main farm

      harvestersCount = harvesters.where((client) => !(client is Farmer)).length;
      farmersCount = harvesters.length - harvestersCount;

      if (args.contains("workers")) {
        //Sorts workers by alphabetical order
        harvesters.sort((harvester1, harvester2) => harvester1.name.compareTo(harvester2.name));

        //Sorts workers by farmer/harvester type
        harvesters.sort((client1, client2) => client1.type.index.compareTo(client2.type.index));

        for (Harvester harvester in harvesters) {
          harvester.filterDuplicates(false);
          harvester.sortPlots();

          showHarvester(harvester, harvestersCount, farmersCount, netspace, args.contains("full"),
              args.contains("workers"), price.rates[harvester.currency]);

          if (harvester != harvesters.last) print(';;');
        }
      } else {
        //Sorts harvesters by farmer/harvester type
        harvesters.sort((client1, client2) => client1.type.index.compareTo(client2.type.index));

        harvesters.remove(farm);

        for (Harvester harvester in harvesters) {
          farm.addHarvester(harvester);
        }

        farm.filterDuplicates(false);
        farm.sortPlots();

        showHarvester(farm, harvestersCount, farmersCount, netspace, args.contains("full"),
            args.contains("workers"), price.rates[farm.currency]);
      }
    } catch (Exception) {
      if (farmersCount == 0)
        print("Error: Farmer not found.");
      else if (harvesters.length > 0)
        print("Error: ${farmersCount} farmers and ${harvestersCount} harvesters found.");
      else
        print("No clients found!");

      //print("${userID} - Exception: ${Exception.toString()}");
    }
  }
}

//gets harvesters linked to user from mysql db
Future<List<Harvester>> _getUserData(String userID) async {
  List<Harvester> harvesters = [];

  try {
    var settings = new mysql.ConnectionSettings(
        host: 'localhost',
        port: 3306,
        user: dotenv.env['MYSQL_USER'],
        password: dotenv.env['MYSQL_PASSWORD'],
        db: 'chiabot');
    var conn = await mysql.MySqlConnection.connect(settings);

    var results = await conn.query("SELECT data FROM farms WHERE user='${userID}'");

    for (var result in results) {
      if (result[0].toString().contains('"type"')) {
        String data = "[" + result[0].toString() + "]";

        if (data.contains('"type":0'))
          harvesters.add(Farmer.fromJson(data));
        else if (data.contains('"type":1')) harvesters.add(Harvester.fromJson(data));
      }
    }

    conn.close();
  }
  //reads from public api in case connection to mysql database fails
  catch (e) {
    String contents = await http.read("http://chiabot.znc.sh/read.php?user=" + userID);

    contents = contents.trim(); //filters last , of send page, can be fixed on server side later

    var clientsSerial = contents
        .replaceAll("[;;]", "")
        .split(';;')
        .where((element) => element != "[]" && element != "")
        .toList();

    for (int i = 0; i < clientsSerial.length; i++) {
      String clientSerial = clientsSerial[i];

      var client;

      //If this object is a farmer then adds it to farmers list, if not adds it to harvesters list
      if (clientSerial.contains('"type":0')) {
        client = Farmer.fromJson(clientSerial);
        harvesters.add(client);
      } else if (clientSerial.contains('"type":1')) {
        client = Harvester.fromJson(clientSerial);
        harvesters.add(client);
      }
    }
  }

  return harvesters;
}

//gets harvesters linked to user from mysql db
void _getUsers() async {
  var settings = new mysql.ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: dotenv.env['MYSQL_USER'],
      password: dotenv.env['MYSQL_PASSWORD'],
      db: 'chiabot');
  var conn = await mysql.MySqlConnection.connect(settings);

  int users = (await conn.query(
          "SELECT user FROM farms WHERE data<>'' AND data<>';' AND user<>'none' group by user"))
      .length;

  int devices = (await conn.query("SELECT id FROM farms WHERE data<>'' AND data<>';'")).length;

  conn.close();

  print("${users} active users and ${devices} active devices");
}

//get price in an isolate
Future<Price> _getPrice() async {
  Price price = Price(dotenv.env['COINMARKETCAP']);
  await price.init();

  return price;
}

showHarvester(Harvester harvester, int harvestersCount, int farmersCount, NetSpace netSpace,
    bool isFull, bool isWorkers, double price,
    [bool discord = true]) {
  String output;

  try {
    if (!isFull) {
      harvestersCount = 0;
      farmersCount = 0;
    }

    String name = (isWorkers) ? Stats.showName(harvester) : '';
    String lastUpdated = ((isFull || isWorkers) && discord)
        ? Stats.showLastUpdated(harvester, farmersCount, harvestersCount)
        : '';

    String main = name +
        Stats.showBalance(harvester, price) +
        Stats.showPlotsInfo(harvester) +
        Stats.showETWEDV(harvester, netSpace, price, !isWorkers) +
        Stats.showNetworkSize(harvester, netSpace) +
        Stats.showFarmedTime(harvester);

    String full = (isFull || isWorkers)
        ? Stats.showPlotTypes(harvester) +
            Stats.showLastPlotInfo(harvester) +
            Stats.showLastNDaysPlots(harvester, 8) +
            Stats.showIncompletePlotsWarning(harvester) +
            Stats.showFilters(harvester) +
            Stats.showSubSlots(harvester)
        : '';

    output = main + full + lastUpdated;

    //removes discord emojis
    if (!discord) {
      try {
        RegExp emojiRegex = RegExp('(:[\\S]+: )');
        RegExp externalEmojiRegex = RegExp('(<:[\\S]+:[0-9]+> )');

        var matches = emojiRegex.allMatches(output).toList();
        matches.addAll(externalEmojiRegex.allMatches(output).toList());

        for (var match in matches)
          output = output.replaceAll(match.group(1), "").replaceAll("**", "");
      } catch (e) {}
    }
  } catch (e) {
    output = "Failed to display stats.";
  }

  print(output);
}
