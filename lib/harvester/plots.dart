import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/hpool/hpool.dart';
import 'package:farmr_client/rpc.dart';
import 'package:universal_io/io.dart' as io;

import 'package:yaml/yaml.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/config.dart';

final Logger log = Logger('Harvester.Plots');

class HarvesterPlots {
  //checks if plot is larger than k32 (for most forks)
  bool checkPlotSize = true;

  //Private list with complete and incomplete plots
  List<Plot> allPlots = [];

  //Returns list of complete and loaded plots
  List<Plot> get plots =>
      allPlots.where((plot) => plot.complete && plot.loaded).toList();

  //Returns list of complete
  List<Plot> get completePlots =>
      allPlots.where((plot) => plot.complete || !checkPlotSize).toList();

  //Returns list of incomplete plots
  List<Plot> get incompletePlots =>
      allPlots.where((plot) => !plot.complete && checkPlotSize).toList();

  //Returns list of og plots
  List<Plot> get ogPlots =>
      allPlots.where((plot) => plot.isOG && plot.loaded).toList();

  //Returns list of nft plots
  List<Plot> get nftPlots =>
      allPlots.where((plot) => plot.isNFT && plot.loaded).toList();

  //Returns list of plots which failed to load
  List<Plot> get failedPlots => allPlots
      .where((plot) => plot.failed || (!plot.complete && checkPlotSize))
      .toList();

  //creates a map with the following structure { 'k32' : 3, 'k33' : 2 } etc.
  Map<String, int> get typeCount => genPlotTypes(plots);

  //Parses chia's config.yaml and finds plot destionation paths
  List<String> listPlotDest(String chiaConfigPath) {
    String configPath = (chiaConfigPath != "")
        ? chiaConfigPath + io.Platform.pathSeparator + "config.yaml"
        : "config.yaml";

    var configYaml = loadYaml(
        io.File(configPath).readAsStringSync().replaceAll("!!set", ""));

    List<String> pathsUnfiltered = (this is HPool)
        ? ylistToStringlist(configYaml['path'])
        : ylistToStringlist(configYaml['harvester']['plot_directories']);

    //Filters duplicate paths
    List<String> pathsFiltered = [];

    for (int i = 0; i < pathsUnfiltered.length; i++) {
      try {
        io.Directory dir = io.Directory(pathsUnfiltered[i]);

        if (dir.existsSync()) {
          //It used to not add empty directories before,
          //but that would mean it would not get the disk space of those directories
          //bool isEmpty =
          //  dir.listSync().where((file) => extension(file.path) == ".plot").toList().length == 0;

          //Adds plot dest if it contains at least one .plot file
          //if (!isEmpty) {
          pathsFiltered.add(dir.absolute.path);
          log.info("Found plot destination directory:" + dir.absolute.path);
          //}
        }
      } catch (err) {
        log.warning("Unable to load " + pathsUnfiltered[i]);
      }
    }

    return pathsFiltered.toSet().toList();
  }

  //returns last bit of plot filename if plot contains '-' (such as chia plotter and madmax)
  //else returns whole filename
  static String getPlotId(String path) {
    final String fileName = basenameWithoutExtension(path);
    return (fileName.contains("-")) ? fileName.split('-').last : fileName;
  }

//makes a list of available plots in all plot destination paths
  Future<void> listPlots(List<String> paths, Config config) async {
    List<Plot> newplots = [];

    for (int i = 0; i < paths.length; i++) {
      var path = paths[i];

      try {
        io.Directory dir = io.Directory(path);

        await dir.list(recursive: false).forEach((file) {
          //Checks if file extension is .plot
          //also checks that it is a File and not a directory
          if (extension(file.path) == ".plot" && file is io.File) {
            final id = getPlotId(file.path);

            bool inCache = (id != null)
                ? allPlots.any((cachedPlot) => cachedPlot.id == id)
                : false;
            bool duplicate =
                (id != null) ? newplots.any((plot) => plot.id == id) : false;

            //If plot id it is in cache then adds old plot information (timestamps, etc.)
            //but updates plot size
            if (inCache && !duplicate) {
              Plot plot =
                  allPlots.firstWhere((cachedPlot) => cachedPlot.id == id);

              //updates file size in case plot was being moved while cached
              if (!plot.complete) {
                io.FileStat stat = io.FileStat.statSync(file.path);
                plot.updateSize(stat.size);
              }

              newplots.add(plot);
            }
            //Adds plot if it's not in cache already
            else if (!duplicate) {
              //print("Found new plot " + id); // UNCOMMENT FOR DEBUGGING PLOT CACHE
              Plot plot = new Plot(file);
              newplots.add(plot);
            }
          }
        });
      } catch (error) {
        log.warning("Failed to list plots in $path\nIs this directory empty?");
        log.info(error);
      }
    }

    allPlots = newplots;

    config.cache!.savePlots(allPlots);
  }

  Future<void> readRPCPlotList(Blockchain blockchain) async {
    try {
      RPCConfiguration rpcConfig = RPCConfiguration(
          blockchain: blockchain,
          service: RPCService.Harvester,
          endpoint: "get_plots",
          dataToSend: {});

      var rpcOutput = await RPCConnection.getEndpoint(rpcConfig);

      List<String> loadedIDs = [];
      List<String> nftIDs = [];

      if (rpcOutput != null &&
          rpcOutput['plots'] != null &&
          rpcOutput['plots'] != null)
        for (var plot in rpcOutput['plots']) {
          if (plot['filename'] is String) {
            try {
              final String id = getPlotId(plot['filename'] as String);

              loadedIDs.add(id);

              //nft plot if pool_public_key is defined
              if (plot['pool_contract_puzzle_hash'] != null) {
                nftIDs.add(id);
              }
            } catch (error) {
              log.info("Failed to get RPC info about plot ${plot['filename']}");
            }
          }
        }

      for (Plot plot in allPlots) {
        if (loadedIDs.length > 0 && !loadedIDs.contains(plot.id))
          plot.loaded = false;
        if (nftIDs.contains(plot.id)) plot.isNFT = true;
      }
    } catch (error) {
      log.warning(
          "Failed to load RPC list of ${blockchain.currencySymbol} plots");
    }
  }

  void filterDuplicates([bool client = true]) {
    final idslist = allPlots.map((plot) => plot.id);
    final idsSet = idslist.toSet();
    final difference = idslist.length - idsSet.length;

    //Removes plots with same ids!
    allPlots.retainWhere((x) {
      if (idsSet.remove(x.id)) {
        return true;
      } else {
        log.info("Found duplicate plot " + x.id);
        return false;
      }
    });

    //Counts how many plots were filtered
    if (client && difference > 0)
      log.warning("Warning: filtering $difference duplicated plots!");
  }

  //makes an id based on end and start timestamps for the last plot, necessary to call notifications webhook
  String lastPlotID() {
    if (completePlots.length > 0) {
      Plot last = lastPlot(completePlots); //last completed plot

      return last.id;
    } else {
      return "0";
    }
  }

  void sortPlots() {
    allPlots.sort((plot1, plot2) => (plot1.begin
        .compareTo(plot2.begin))); //Sorts plots from oldest to newest
  }

  //sorts plots into typeCount map
  static Map<String, int> genPlotTypes(List<Plot> plots) {
    Map<String, int> typeCount = {};

    for (Plot plot in plots) {
      String type = plot.plotSize;
      if (type.startsWith("k")) {
        typeCount.putIfAbsent(type, () => 0);
        typeCount.update(type, (value) => value + 1);
      }
    }

    return typeCount;
  }
}

//Converts a YAML List to a String list
//Used to parse chia's config.yaml
List<String> ylistToStringlist(YamlList input) {
  List<String> output = [];
  for (int i = 0; i < input.length; i++) {
    output.add(input[i].toString());
  }
  return output;
}
