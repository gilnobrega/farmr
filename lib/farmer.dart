import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'config.dart';
import 'harvester.dart';

class Farmer extends Harvester {

  String _status;
  String get status => _status;

  double _balance = 0;
  double get balance => _balance; //hides balance if string

  String _size = "0";
  String get size => _size;

  String _networkSize = "0";
  String get networkSize => _networkSize;

  int _plotNumber = 0;
  int get plotNumber => _plotNumber;

  @override
  ClientType _type = ClientType.Farmer;
  @override
  ClientType get type => _type;

  @override
  Map toJson() => {
        'status': status,
        'balance': balance,
        'size': size,
        'networkSize': networkSize,
        'plotNumber': plotNumber,
        'plots': allPlots, //important
        'totalDiskSpace': totalDiskSpace,
        'freeDiskSpace': freeDiskSpace,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'lastUpdatedString': lastUpdatedString,
        'type': type.index,
      };

  Farmer(Config config) : super(config) {

    //runs chia farm summary if it is a farmer
      var result = io.Process.runSync(config.binPath, ["farm", "summary"]);
      List<String> lines = result.stdout.toString().replaceAll("\r", "").split('\n');
      try {
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i];

          if (line.startsWith("Total chia farmed: "))
            _balance =
                (config.showBalance) ? double.parse(line.split('Total chia farmed: ')[1]) : -1.0;
          else if (line.startsWith("Farming status: "))
            _status = line.split("Farming status: ")[1];
          else if (line.startsWith("Plot count: "))
            _plotNumber = int.parse(line.split("Plot count: ")[1]);
          else if (line.startsWith("Total size of plots: "))
            _size = line.split("Total size of plots: ")[1];
          else if (line.startsWith("Estimated network space: "))
            _networkSize = line.split("Estimated network space: ")[1];
        }
      } catch (exception) {
        print("Error parsing Farm info.");
      }
  }

  //Server side function to read farm from json file
  Farmer.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    _status = object['status'];
    _balance = object['balance'];
    _size = object['size'];
    _networkSize = object['networkSize'];
    _plotNumber = object['plotNumber'];

  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0) supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;
  }

}
