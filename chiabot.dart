import 'dart:convert';
import 'dart:io' as io;
import 'dart:core';
import 'package:http/http.dart' as http;

import 'lib/farm.dart';
import 'lib/config.dart';

final Duration delay = Duration(minutes: 10); //10 minutes delay between updates

main(List<String> args) async {
  //Kills command on ctrl c
  io.ProcessSignal.sigint.watch().listen((signal) {
    io.exit(0);
  });

  //Initializes config, either creates a new one or loads a config file
  Config config = new Config(
      (args.length == 1 && (args[0] == "harvester" || args[0] == '-h'))); //checks if is harvester

  await config.init();

  while (true) {
    String lastPlotID = "";
    String balance = "";
    String status = "";
    String farmJson = "";

    //PARSES DATA
    try {
      Farm farm = new Farm(config);
      await farm.init();

      //Throws exception in case no plots were found
      if (farm.plots.length == 0)
        throw Exception(
            "No plots have been found! Make sure your user has access to the folders where plots are stored.");

      lastPlotID = farm.lastPlotID();
      balance = farm.balance.toString();
      status = farm.status;

      farmJson = jsonEncode(farm);
    } catch (exception) {
      print("Oh no! Something went wrong.");
      print(exception.toString());
    }

    //SENDS DATA TO SERVER
    try {
      Farm farmcopy = Farm.fromJson("[" + farmJson + "]");

      //clones farm so it can clear ids before sending them to server
      farmcopy.clearIDs();

      //String that's actually sent to server
      String sendJson = jsonEncode(farmcopy);

      String notifyOffline = (config.sendOfflineNotifications) ? '1' : '0';

      String url =
          "https://chiabot.znc.sh/send.php?id=" + config.id + "&notifyOffline=" + notifyOffline;

      //Adds the following if sendPlotNotifications is enabled then it will send plotID
      if (config.sendPlotNotifications) url += "&lastPlot=" + lastPlotID;

      //If the client is a farmer and it is farming and sendBalanceNotifications is enabled then it will send balance
      if (config.type == ClientType.Farmer &&
          config.sendBalanceNotifications &&
          status == "Farming") url += "&balance=" + Uri.encodeComponent(balance.toString());

      //print(url);  //UNCOMMENT FOR DEBUG PURPOSES

      http.post(url, body: {"data": sendJson});

      String type = (config.type == ClientType.Farmer) ? "farmer" : "harvester";

      print("Sent " +
          type +
          " report to server.\nRetrying in " +
          delay.inMinutes.toString() +
          " minutes");

      if (io.Platform.isWindows) print("Do NOT close this window.");
    } catch (exception) {
      print("Oh no, failed to connect to server!");
      print(exception.toString());
    }

    await Future.delayed(delay);
  }
}
