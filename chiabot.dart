import 'dart:convert';
import 'dart:io' as io;
import 'dart:core';
import 'package:http/http.dart' as http;

import 'farm.dart';

import 'config.dart';

main(List<String> args) async {
  //Kills command on ctrl c
  io.ProcessSignal.sigint.watch().listen((signal) {
    io.exit(0);
  });

  //Initializes config, either creates a new one or loads a config file
  Config config = new Config((args.length == 1 &&
      (args[0] == "harvester" || args[0] == '-h'))); //checks if is harvester

  await config
      .init((args.length == 1 && (args[0] == "harvester" || args[0] == '-h')));

  Duration delay = Duration(minutes: 10); //10 minutes delay between updates

  while (true) {
    String serialFarm;
    String lastPlotID = "";
    String balance = "";

    try {
      Farm farm = new Farm(config);
      await farm.init();

      //Throws exception in case no plots were found
      if (farm.plots.length == 0) throw Exception("No plots have been found! Make sure your user has access to the folders where plots are stored.");

      lastPlotID = farm.lastPlotID();
      balance = farm.balance.toString();

      serialFarm = jsonEncode(farm);
    } catch (exception) {
      print("Oh no! Something went wrong.");
      print(exception.toString());
    }

    try {
      String url = "https://chiabot.znc.sh/send.php?id=" + config.id;

      //Adds the following if sendPlotNotifications is enabled then it will send plotID
      if (config.sendPlotNotifications) url += "&lastPlot=" + lastPlotID;

      //If the client is a farmer and sendBalanceNotifications is enabled then it will send balance
      if (config.type == ClientType.Farmer && config.sendBalanceNotifications)
        url += "&balance=" + Uri.encodeComponent(balance.toString());

      //print(url);  //UNCOMMENT FOR DEBUG PURPOSES

      await http.post(url, body: {"data": serialFarm});

      String type = (config.type == ClientType.Farmer) ? "farmer" : "harvester";

      print("Sent " +
          type +
          " report to server.\nRetrying in " +
          delay.inMinutes.toString() +
          " minutes\n" +
          "Do NOT close this window.");
    } catch (exception) {
      print("Oh no, failed to connect to server!");
      print(exception.toString());
    }

    await Future.delayed(delay);
  }
}
