import 'dart:convert';
import 'dart:core';

import 'package:farmr_client/config.dart';
import 'package:farmr_client/wallets/wallet.dart';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:proper_filesize/proper_filesize.dart';
import 'package:universal_io/io.dart' as io;

import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/hpool/hpool.dart';
import 'package:farmr_client/stats.dart';
import 'package:farmr_client/server/price.dart';
import 'package:farmr_client/server/netspace.dart';

Future<void> main(List<String> args) async {
  dotenv.load();

  String blockchain = "xch";
  if (args.contains("--blockchain"))
    blockchain = args[args.indexOf("--blockchain") + 1].toLowerCase();

  //prints farmr status
  if (args[0] == "status") {
    _getUsers();
  }
  //generates cache files
  else if (args[0] == "cron") {
    Price price = Price();
    //forces generation of price.json
    await price.init(true);

    NetSpace netSpace = NetSpace();
    //forces generation of netspace.json
    await netSpace.init(true);
  } else if (args[0] == "price") {
    Price price = await _getPrice();

    final List<String> currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
    final List<String> cryptos = ['BTC', 'ETH'];

    for (String currency in currencies)
      print(
          "XCH/$currency: **${price.rates[currency]?.rate.toStringAsFixed(2)}** (${price.rates[currency]?.changeAbsolute} $currency, ${price.rates[currency]?.changeRelative}%)");

    print("");

    for (String currency in cryptos)
      print(
          "XCH/$currency: **${price.rates[currency]?.rate.toStringAsPrecision(3)}** (${price.rates[currency]?.changeRelative}%)");

    Duration difference = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(price.timestamp));

    String source = ' - coingecko.com';

    if (difference.inMinutes > 0)
      print("-- last updated ${difference.inMinutes} minutes ago" + source);
    else
      print("-- last updated ${difference.inSeconds} seconds ago" + source);
  } else if (args[0] == "netspace") {
    NetSpace netspace = NetSpace();
    await netspace.init();

    var entries = netspace.pastSizes.entries.toList();
    entries.sort((entry1, entry2) =>
        int.parse(entry2.key).compareTo(int.parse(entry1.key)));

    print("Current Netspace: **${netspace.humanReadableSize}**");
    print("Last 24 hours: ${netspace.dayDifference}\n");

    int until = 6;
    for (int i = 0; (i <= until && i < entries.length - 1); i++) {
      var pastSize = entries[i];

      DateTime pastSizeDate =
          DateTime.fromMillisecondsSinceEpoch(int.parse(pastSize.key));

      String date = DateFormat('MMM dd').format(pastSizeDate);
      String size =
          ProperFilesize.generateHumanReadableFilesize(pastSize.value.abs());

      String growth = (i != until && i != entries.length - 1)
          ? '(' + NetSpace.percentageDiff(pastSize, entries[i + 1], true) + ')'
          : '';

      print("$date: $size $growth");
    }

    print("Values recorded at 9pm UTC");

    Duration difference = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(netspace.timestamp));

    if (difference.inMinutes > 0)
      print(
          "-- last updated ${difference.inMinutes} minutes ago - ${netspace.source}");
    else
      print(
          "-- last updated ${difference.inSeconds} seconds ago - ${netspace.source}");
  } else {
    //Discord User ID
    String userID = args[0];

    Price price = Price();

    List<Harvester> harvesters = [];

    int farmersCount = 0;
    int harvestersCount = 0;

    NetSpace netspace = NetSpace();

    try {
      //Gets user data and Price in parallel, since both are parsed from web
      final async1 = _getUserData(userID, blockchain);

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
      harvesters.sort((client2, client1) => (client1
          .lastUpdated.millisecondsSinceEpoch
          .compareTo(client2.lastUpdated.millisecondsSinceEpoch)));

      harvestersCount =
          harvesters.where((client) => !(client is Farmer)).length;
      farmersCount = harvesters.length - harvestersCount;

      Farmer farm = harvesters
          .where((client) => (client is Farmer || client is HPool))
          .first as Farmer; //Selects newest farm as main farm

      if (args.contains("workers")) {
        //Sorts workers by alphabetical order
        harvesters.sort((harvester1, harvester2) =>
            harvester1.name.compareTo(harvester2.name));

        //Sorts workers by farmer/harvester type
        harvesters.sort((client1, client2) =>
            client1.type.index.compareTo(client2.type.index));

        for (Harvester harvester in harvesters) {
          harvester.filterDuplicates(false);
          harvester.sortPlots();

          print(Stats.showHarvester(
              harvester,
              harvestersCount,
              farmersCount,
              //for other blockchains loads local value for netspace
              (blockchain == "xch") ? netspace : farm.netSpace,
              args.contains("full"),
              args.contains("workers"),
              //doesnt load Price for blockchains other than chia
              (blockchain == "xch")
                  ? price.rates[harvester.currency]
                  : Price().rates[harvester.currency]));

          if (harvester != harvesters.last) print(';;');
        }
      } else {
        //Sorts harvesters by farmer/harvester type
        harvesters.sort((client1, client2) =>
            client1.type.index.compareTo(client2.type.index));

        harvesters.remove(farm);

        for (Harvester harvester in harvesters) {
          farm.addHarvester(harvester);
        }

        farm.filterDuplicates(false);
        farm.sortPlots();

        if (args.contains("wallets")) {
          for (Wallet wallet in farm.wallets) {
            print(Stats.showWalletInfo(wallet, blockchain));
            if (wallet != farm.wallets.last) print(';;');
          }
        } else
          print(Stats.showHarvester(
              farm,
              harvestersCount,
              farmersCount,
              //for other blockchains loads local value for netspace
              (blockchain == "xch") ? netspace : farm.netSpace,
              args.contains("full"),
              args.contains("workers"),
              //doesnt load Price for blockchains other than chia
              (blockchain == "xch")
                  ? price.rates[farm.currency]
                  : Price().rates[farm.currency]));
      }
    } catch (Exception) {
      if (farmersCount == 0) print("Error: Farmer not found.");
      if (harvesters.length > 0)
        print(
            "Error: $farmersCount farmers and $harvestersCount harvesters found.");
      else
        print(
            "No clients found! Find out how you can install farmr client in your farmer/harvester in <#838789194696097843>");

      //print("${userID} - Exception: ${Exception.toString()}");
    }
  }

  io.exit(0); //fixes issue where some commands would hang for some users
}

//gets harvesters linked to user from mysql db
//if userID is null then it gets all harvesters from database
Future<List<Harvester>> _getUserData(String userID, String blockchain) async {
  List<Harvester> harvesters = [];

  try {
    var settings = new mysql.ConnectionSettings(
        host: 'localhost',
        port: 3306,
        user: dotenv.env['MYSQL_USER'],
        password: dotenv.env['MYSQL_PASSWORD'],
        db: 'chiabot');
    var conn = await mysql.MySqlConnection.connect(settings);

    String mysqlQuery = "SELECT data FROM farms WHERE user='$userID'";

    if (userID == "all")
      mysqlQuery = "SELECT data FROM farms WHERE data<>'' and data<>';;'";

    var results = await conn.query(mysqlQuery);
    for (var result in results) {
      if (result[0].toString().contains('"type"')) {
        String data = result[0].toString();
        var clientData = jsonDecode(data);

        if (clientData['type'] == 3 ||
            clientData['type'] == 4 ||
            ClientType.values[clientData['type']] == ClientType.Farmer)
          harvesters.add(Farmer.fromJson(clientData));
        else if (ClientType.values[clientData['type']] == ClientType.Harvester)
          harvesters.add(Harvester.fromJson(clientData));
        else if (ClientType.values[clientData['type']] == ClientType.HPool)
          harvesters.add(HPool.fromJson(clientData));
      }
    }

    conn.close();
  }
  //reads from public api in case connection to mysql database fails
  catch (e) {
    String contents =
        await http.read(Uri.parse("http://farmr.net/read.php?user=$userID"));

    contents = contents
        .trim(); //filters last , of send page, can be fixed on server side later

    var clientsSerial = contents
        .replaceAll("[;;]", "")
        .split(';;')
        .where((element) => element != "[]" && element != "")
        .toList();

    for (int i = 0; i < clientsSerial.length; i++) {
      var clientData = jsonDecode(clientsSerial[i])[0];

      //If this object is a farmer then adds it to farmers list, if not adds it to harvesters list
      if (clientData['type'] == 3 ||
          clientData['type'] == 4 ||
          ClientType.values[clientData['type']] == ClientType.Farmer) {
        final client = Farmer.fromJson(clientData);
        harvesters.add(client);
      } else if (ClientType.values[clientData['type']] ==
          ClientType.Harvester) {
        final client = Harvester.fromJson(clientData);
        harvesters.add(client);
      } else if (ClientType.values[clientData['type']] == ClientType.HPool) {
        final client = HPool.fromJson(clientData);
        harvesters.add(client);
      }
    }
  }

  //filters harvesters with specific blockchain
  harvesters =
      harvesters.where((harvester) => harvester.crypto == blockchain).toList();

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

  int devices =
      (await conn.query("SELECT id FROM farms WHERE data<>'' AND data<>';'"))
          .length;

  conn.close();

  print("$users active users and $devices active devices");
}

//get price in an isolate
Future<Price> _getPrice() async {
  Price price = Price();
  await price.init();

  return price;
}
