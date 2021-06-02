import 'package:chiabot/config.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/debug.dart' as Debug;

class HPool extends Harvester {
  @override
  String get status => "HPool :nauseated_face:";

  @override
  final ClientType type = ClientType.HPool;

  HPool(Config config, Debug.Log log, [String version = ''])
      : super(config, log, version);

  HPool.fromJson(dynamic json) : super.fromJson(json) {}

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0)
      supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;
    drivesCount += harvester.drivesCount;

    //Disables avg, median, etc. in !chia full
    this.disableDetailedTimeStats();

    //adds swar pm jobs
    swarPM?.jobs.addAll(harvester.swarPM?.jobs ?? []);
  }
}
