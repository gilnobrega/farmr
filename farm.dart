import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart';
import 'package:decimal/decimal.dart';

import 'plot.dart';
import 'config.dart';

class Farm {
  Config _config;

  final String id = Uuid().v4();

  String _status;
  String get status => _status;

  double _balance = 0;
  double get balance => _balance; //hides balance if string

  String _size = "0";
  String get size => _size;

  String _networkSize = "0";
  String get networkSize => _networkSize;

  Duration _etw = Duration(seconds: 0);
  Duration get etw => _etw;

  int _plotNumber = 0;
  int get plotNumber => _plotNumber;

  List<Plot> _plots;
  List<Plot> get plots => _plots;

  //Timestamp to when the farm was last parsed
  DateTime _lastUpdated;
  DateTime get lastUpdated => _lastUpdated;

  //Farmer or Harvester
  ClientType _type;
  ClientType get type => _type;

  Map toJson() => {
        'status': status,
        'balance': balance,
        'size': size,
        'networkSize': networkSize,
        'etw': etw.inMilliseconds,
        'plotNumber': plotNumber,
        'plots': plots,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'type': type.index
      };

  Farm(Config config) {
    _config = config;
    _type = config.type;

    //runs chia farm summary if it is a farmer
    if (config.type == ClientType.Farmer) {
      var result = io.Process.runSync(config.binPath, ["farm", "summary"]);
      List<String> lines =
          result.stdout.toString().replaceAll("\r", "").split('\n');

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        if (line.startsWith("Total chia farmed: "))
          _balance = (config.showBalance)
              ? double.parse(line.split('Total chia farmed: ')[1])
              : -1.0;
        else if (line.startsWith("Farming status: "))
          _status = line.split("Farming status: ")[1];
        else if (line.startsWith("Plot count: "))
          _plotNumber = int.parse(line.split("Plot count: ")[1]);
        else if (line.startsWith("Total size of plots: "))
          _size = line.split("Total size of plots: ")[1];
        else if (line.startsWith("Estimated network space: "))
          _networkSize = line.split("Estimated network space: ")[1];
        else if (line.startsWith("Expected time to win: "))
          _etw = Duration(
              days: int.parse(
                  line.split("Expected time to win: ")[1].split(" days")[0]));
      }
    }

    _lastUpdated = DateTime.now();
  }

  //Server side function to read farm from json file
  Farm.fromJson(String json) {
    var object = jsonDecode(json)[0];

    _status = object['status'];
    _balance = object['balance'];
    _size = object['size'];
    _networkSize = object['networkSize'];
    _etw = Duration(milliseconds: object['etw']);
    _plotNumber = object['plotNumber'];
    _plots = [];

    for (int i = 0; i < object['plots'].length; i++) {
      _plots.add(Plot.fromJson(object['plots'][i]));
    }

    _lastUpdated = DateTime.fromMillisecondsSinceEpoch(object['lastUpdated']);

    _type = ClientType.values[object['type']];
  }

  Future<void> init() async {
    String configPath = _config.configPath + "config.yaml";

    //LOADS CHIA CONFIG FILE AND PARSES PLOT DIRECTORIES
    var config = loadYaml(
        io.File(configPath).readAsStringSync().replaceAll("!!set", ""));

    List<String> paths =
        ylistToStringlist(config['harvester']['plot_directories']);

    _plots = await listPlots(paths);

    _lastUpdated = DateTime.now();
  }

  //sums file sizes of all plots in farm
  int sumSize() {
    int calcSize = 0;
    for (int i = 0; i < plots.length; i++) calcSize += plots[i].size;

    return calcSize;
  }

  //Estimates ETW in days
  //Decimals are more precise (in theory)
  Decimal estimateETW() {
    Decimal size = Decimal.parse(sumSize().toString());
    Decimal networkSizeBytes = Decimal.parse(
            networkSize.replaceAll(" PiB", "")) *
        Decimal.parse(1e15
            .toString()); //THIS WILL BREAK ONE DAY 1 PIB = 140737488355328 bytes

    int blockRewards = 2; //xch per block
    double blocks = 32.0; //32 blocks per 10 minutes

    Decimal calc = (networkSizeBytes / size) /
        Decimal.parse((blocks * 6.0 * 24.0).toString());

    return calc;
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Farm harvester) {
    plots.addAll(harvester.plots);
  }
}

//Converts a YAML List to a String list
List<String> ylistToStringlist(YamlList input) {
  List<String> output = [];
  for (int i = 0; i < input.length; i++) {
    output.add(input[i].toString());
  }
  return output;
}

//makes a list of available plots in all plot destination paths
Future<List<Plot>> listPlots(List<String> paths) async {
  List<Plot> plots = [];

  for (int i = 0; i < paths.length; i++) {
    var path = paths[i];

    io.Directory dir = new io.Directory(path);
    if (dir.existsSync()) {
      await dir.list(recursive: false).forEach((file) {
        //Checks if file extension is .plot
        if (extension(file.path) == ".plot") plots.add(new Plot(file));
      });
    }
  }

//Sorts plots from oldest to newest
  plots.sort((plot1, plot2) => (plot1.begin.compareTo(plot2.begin)));
  return plots;
}
