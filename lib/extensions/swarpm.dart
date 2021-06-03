import 'dart:convert';
import 'package:universal_io/io.dart' as io;

class SwarPM {
  List<Job> jobs = [];

  Map toJson() => {"jobs": jobs};

  SwarPM([String managerPath = ""]) {
    if (managerPath != "") {
      String jsonOutput = '';

      final oldDir = io.Directory.current;

      try {
        //changes working directory to swar's pm
        io.Directory.current = managerPath;
        if (io.Platform.isWindows) {
          jsonOutput =
              io.Process.runSync("python", const ["manager.py", "json"]).stdout;
        } else {
          jsonOutput = io.Process.runSync(
              "/usr/bin/env", const ["python3", "manager.py", "json"]).stdout;
        }

        dynamic jsonObject = jsonDecode(jsonOutput);

        for (var jobObject in jsonObject["jobs"]) {
          Job job = Job(jobObject);
          jobs.add(job);
        }
      } catch (e) {
        print(
            "Failed to get info about Swar's Chia Plot Manager.\nMake sure you're running version >0.1.0");
      }

      //restores old working directory
      io.Directory.current = oldDir;
    }
  }

  SwarPM.fromJson(dynamic json) {
    if (json['jobs'] != null) {
      for (var job in json['jobs']) jobs.add(Job.fromJson(job));
    }
  }
}

class Job {
  late String number;
  late String name;
  late String size;
  late String id;
  late String started;
  late String elapsed;
  late int phase;
  late String phaseTimes;
  late String percentage;
  late String space;

  Map toJson() => {
        "number": number,
        "name": name,
        "size": size,
        "id": id,
        "started": started,
        "elapsed": elapsed,
        "phase": phase,
        "phaseTimes": phaseTimes,
        "percentage": percentage,
        "space": space
      };

  Job(dynamic json) {
    number = json[0];
    name = json[1];
    size = json[2];
    id = json[3];
    started = json[5];
    elapsed = json[6];
    phase = json[7];
    phaseTimes = json[8];
    percentage = json[9];
    space = json[10];
  }

  Job.fromJson(dynamic json) {
    if (json['name'] != null) name = json['name'];
    if (json['number'] != null) number = json['number'];
    if (json['size'] != null) size = json['size'];
    if (json['id'] != null) id = json['id'];
    if (json['started'] != null) started = json['started'];
    if (json['elapsed'] != null) elapsed = json['elapsed'];
    if (json['percentage'] != null) percentage = json['percentage'];
    if (json['phase'] != null) phase = json['phase'];
    if (json['phaseTimes'] != null) phaseTimes = json['phaseTimes'];
    if (json['space'] != null) space = json['space'];
  }
}
