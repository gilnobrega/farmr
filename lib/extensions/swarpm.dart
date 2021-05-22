import 'dart:convert';
import 'dart:io' as io;

class SwarPM {
  List<Job> jobs = [];

  Map toJson() => {"jobs": jobs};

  SwarPM(String managerPath) {
    String jsonOutput = '';

    if (io.Platform.isWindows) {
      jsonOutput =
          io.Process.runSync("python", ["manager.py", "json"], runInShell: true)
              .stdout;
    } else {
      jsonOutput =
          io.Process.runSync("/usr/bin/env", ["python3", "manager.py", "json"])
              .stdout;
    }

    dynamic jsonObject = jsonEncode(jsonOutput);

    for (var jobObject in jsonObject["jobs"]) {
      Job job = Job(jobObject);
      jobs.add(job);
    }
  }

  SwarPM.fromJson(dynamic json) {
    if (json['jobs'] != null) jobs = json['jobs'];
  }
}

class Job {
  String number;
  String name;
  String size;
  String id;
  String started;
  String elapsed;
  int phase;
  String phaseTimes;
  String percentage;
  String space;

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
        "space": size
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
    if (json['phase'] != null) phase = json['phase'];
    if (json['phaseTimes'] != null) phaseTimes = json['phaseTimes'];
    if (json['space'] != null) space = json['space'];
  }
}
