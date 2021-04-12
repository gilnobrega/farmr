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
  Config config = new Config(
      (args.length == 1 && (args[0] == "harvester" || args[0] == '-h'))
          ? true
          : false); //checks if is harvester

  Duration delay = Duration(minutes: 10); //10 minutes delay between updates

  while (true) {
    try {
      Farm farm = new Farm(config);
      await farm.init();

      //Throws exception in case no plots were found
      if (farm.plots.length == 0) throw Exception("No plots have been found!");

      String serialFarm = jsonEncode(farm);
    } catch (Exception) {
      print("Oh no! Something went wrong.");
    }

    //print(serialFarm); uncomment for debug purposes

    try {
      await http.post("https://chiabot.znc.sh/send.php?id=" + config.id,
          body: {"data": serialFarm});

      String type = (config.type == ClientType.Farmer) ? "farmer" : "harvester";

      print("Sent " +
          type +
          " report to server!\nRetrying in " +
          delay.inMinutes.toString() +
          " minutes");
    } catch (Exception) {
      print("Oh no, failed to connect to server!");
    }

    await Future.delayed(delay);
  }
}
