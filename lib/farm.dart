import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart';

import 'package:universal_disk_space/universal_disk_space.dart' as uds;

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

  int _plotNumber = 0;
  int get plotNumber => _plotNumber;

  List<String> _plotDests = []; //plot destination paths

  List<Plot> _plots;
  List<Plot> get plots => _plots;

  //Timestamp to when the farm was last parsed
  DateTime _lastUpdated;
  DateTime get lastUpdated => _lastUpdated;

  String _lastUpdatedString = "1971-01-01";
  String get lastUpdatedString => _lastUpdatedString;

  //Farmer or Harvester
  ClientType _type;
  ClientType get type => _type;

  //Total disk space in bytes
  int _totalDiskSpace = 0;
  int get totalDiskSpace => _totalDiskSpace;

  //Free disk space in bytes
  int _freeDiskSpace = 0;
  int get freeDiskSpace => _freeDiskSpace;

  //sets this to false if the farmer or one of the harvesters didnt report disk space
  bool _supportDiskSpace = true;
  bool get supportDiskSpace => _supportDiskSpace;

  Map toJson() => {
        'status': status,
        'balance': balance,
        'size': size,
        'networkSize': networkSize,
        'plotNumber': plotNumber,
        'plots': plots,
        'totalDiskSpace': totalDiskSpace,
        'freeDiskSpace': freeDiskSpace,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'lastUpdatedString': lastUpdatedString,
        'type': type.index,
      };

  Farm(Config config) {
    _config = config;
    _plots = config.plots; //loads plots from cache
    _type = config.type;

    //runs chia farm summary if it is a farmer
    if (config.type == ClientType.Farmer) {
      var result = io.Process.runSync(config.binPath, ["farm", "summary"]);
      List<String> lines =
          result.stdout.toString().replaceAll("\r", "").split('\n');
      try {
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
        }
      } catch (exception) {
        print("Error parsing Farm info.");
      }
    }

    _lastUpdated = DateTime.now();
    _lastUpdatedString = dateToString(_lastUpdated);
  }

  //Server side function to read farm from json file
  Farm.fromJson(String json) {
    var object = jsonDecode(json)[0];

    _status = object['status'];
    _balance = object['balance'];
    _size = object['size'];
    _networkSize = object['networkSize'];
    _plotNumber = object['plotNumber'];
    _plots = [];

    for (int i = 0; i < object['plots'].length; i++) {
      _plots.add(Plot.fromJson(object['plots'][i]));
    }

    if (object['totalDiskSpace'] != null && object['freeDiskSpace'] != null) {
      _totalDiskSpace = object['totalDiskSpace'];
      _freeDiskSpace = object['freeDiskSpace'];

      //if one of these values is 0 then it will assume that something went wrong in parsing disk space
      //or the client was outdated
      if (_totalDiskSpace == 0 || _freeDiskSpace == 0)
        _supportDiskSpace = false;
    } else
      _supportDiskSpace = false;

    _lastUpdated = DateTime.fromMillisecondsSinceEpoch(object['lastUpdated']);

    if (object['lastUpdatedString'] != null)
      _lastUpdatedString = object['lastUpdatedString'];

    _type = ClientType.values[object['type']];
  }

  Future<void> init() async {
    //LOADS CHIA CONFIG FILE AND PARSES PLOT DIRECTORIES
    _plotDests = listPlotDest();

    await listPlots(_plotDests);

    filterDuplicates(); //removes duplicate ids

    _lastUpdated = DateTime.now();

    await getDiskSpace();
  }

  //Parses chia's config.yaml and finds plot destionation paths
  List<String> listPlotDest() {
    String configPath = _config.configPath + "config.yaml";

    var config = loadYaml(
        io.File(configPath).readAsStringSync().replaceAll("!!set", ""));

    List<String> pathsUnfiltered =
        ylistToStringlist(config['harvester']['plot_directories']);

    //Filters duplicate paths
    List<String> pathsFiltered = [];

    for (int i = 0; i < pathsUnfiltered.length; i++) {
      io.Directory dir = io.Directory(pathsUnfiltered[i]);

      if (dir.existsSync()) pathsFiltered.add(dir.absolute.path);
    }

    return pathsFiltered.toSet().toList();
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Farm harvester) {
    plots.addAll(harvester.plots);

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0)
      _supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    _totalDiskSpace += harvester.totalDiskSpace;
    _freeDiskSpace += harvester.freeDiskSpace;
  }

  void sortPlots() {
    plots.sort((plot1, plot2) => (plot1.begin
        .compareTo(plot2.begin))); //Sorts plots from oldest to newest
  }

  //makes an id based on end and start timestamps for the last plot, necessary to call notifications webhook
  String lastPlotID() {
    Plot last = lastPlot(plots);

    String id = "0"; //if plot notificationd are off then it will default to 0

    if (_config.sendPlotNotifications) id = last.id;

    return id;
  }

  //Gets info about total and available disk space, there's a library for each platform
  Future<void> getDiskSpace() async {
    try {
      // uses own universal_disk_space library
      uds.DiskSpace diskspace = new uds.DiskSpace();
      List<uds.Disk> disks = [];

      for (int i = 0; i < _plotDests.length; i++) {
        uds.Disk currentdisk = diskspace.getDisk(_plotDests[i]);

        //only adds disk sizes/space if it has not been added before
        if (!disks.contains(currentdisk)) {
          disks.add(currentdisk);
          _totalDiskSpace += currentdisk.totalSize;
          _freeDiskSpace += currentdisk.availableSpace;
        }
      }

      //Sets both variables to 0 if getting one disk free space fails
    } catch (e) {
      _freeDiskSpace = 0;
      _totalDiskSpace = 0;
      print("Can't get disk information about one of your drives.");
      print(e.toString());
    }

    //If it can't get one of those values then it will not show disk space
    if (_totalDiskSpace == 0 || _freeDiskSpace == 0) _supportDiskSpace = false;
  }

  void filterDuplicates() {
//Removes plots with same ids!
    final ids = plots.map((plot) => plot.id).toSet();
    plots.retainWhere((x) => ids.remove(x.id));
  }

//makes a list of available plots in all plot destination paths
  void listPlots(List<String> paths) async {
    List<Plot> newplots = [];

    for (int i = 0; i < paths.length; i++) {
      var path = paths[i];

      io.Directory dir = new io.Directory(path);

      await dir.list(recursive: false).forEach((file) {
        //Checks if file extension is .plot
        if (extension(file.path) == ".plot") {
          Plot plot = new Plot(file);

          bool inCache = plots.any((cachedPlot) => cachedPlot.id == plot.id);

          //If plot id it is in cache then adds old plot information (timestamps, etc.)
          if (inCache) {
            newplots.add(
                plots.firstWhere((cachedPlot) => cachedPlot.id == plot.id));
          }
          //Adds plot if it's not in cache already
          else {
            newplots.add(plot);
            //print("Added new plot: ${plot.id}");
          }
        }
      });
    }

    _plots = newplots;

    _config.savePlotsCache(plots);
  }

  //clears plots ids before sending info to server
  void clearIDs() {
    for (int i = 0; i < _plots.length; i++) _plots[i].clearID();
  }
}
