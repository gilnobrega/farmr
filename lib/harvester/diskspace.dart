import 'dart:core';

import 'package:universal_disk_space/universal_disk_space.dart' as uds;
import 'package:logging/logging.dart';

final Logger log = Logger('Harvester.DiskSpace');

class HarvesterDiskSpace {
  //Total disk space in bytes
  int totalDiskSpace = 0;

  //Free disk space in bytes
  int freeDiskSpace = 0;

  //sets this to false if the farmer or one of the harvesters didnt report disk space
  bool supportDiskSpace = true;

  //Gets info about total and available disk space, there's a library for each platform
  Future<void> getDiskSpace(List<String> plotDests) async {
    uds.DiskSpace diskspace;
    try {
      // uses own universal_disk_space library
      diskspace = new uds.DiskSpace();

      List<uds.Disk> disks = [];

      for (int i = 0; i < plotDests.length; i++) {
        uds.Disk currentdisk = diskspace.getDisk(plotDests[i]);

        //only adds disk sizes/space if it has not been added before
        if (!disks.contains(currentdisk)) {
          disks.add(currentdisk);
          totalDiskSpace += currentdisk.totalSize;
          freeDiskSpace += currentdisk.availableSpace;
        }
      }

      //Sets both variables to 0 if getting one disk free space fails
    } catch (e) {
      freeDiskSpace = 0;
      totalDiskSpace = 0;
      log.warning("Can't get disk information about one of your drives.");
      log.info("Disks:\n{diskspace}");
      log.info(e.toString());
    }

    //If it can't get one of those values then it will not show disk space
    if (totalDiskSpace == 0 || freeDiskSpace == 0) supportDiskSpace = false;
  }
}
