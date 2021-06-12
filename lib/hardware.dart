import "package:system_info/system_info.dart";
import 'package:logging/logging.dart';
import "package:collection/collection.dart";

Logger log = Logger("Hardware");

class Hardware {
  String _os = "";
  String get os => _os;

  List<CPU> cpus = [];

  List<Memory> memories = [];

  toJson() => {"os": os, "cpus": cpus, "memories": memories};

  Hardware.fromJson(dynamic json) {
    if (json['os'] != null) _os = json['os'];

    if (json['cpus'] != null)
      for (var cpu in json['cpus']) cpus.add(CPU.fromJson(cpu));

    if (json['memories'] != null)
      for (var memory in json['memories'])
        memories.add(Memory.fromJson(memory));
  }

  Hardware([List<Memory> pastMemories = const []]) {
    memories.addAll(pastMemories);

    try {
      _os = "${SysInfo.operatingSystemName} ${SysInfo.operatingSystemVersion}";

      //groups threads in sockets and then counts them
      var sysProcessors =
          SysInfo.processors.groupListsBy((element) => element.socket);

      for (var cpu in sysProcessors.entries) {
        int socket = cpu.key;
        List<ProcessorInfo> info = cpu.value;

        cpus.add(CPU(socket, info.first.name, info.length,
            info.first.architecture.toString()));
      }

      //gets current memory values
      Memory currentMemory = Memory(
          SysInfo.getTotalPhysicalMemory(),
          SysInfo.getFreePhysicalMemory(),
          SysInfo.getTotalVirtualMemory(),
          SysInfo.getFreeVirtualMemory());

      //checks if any memory in the list shares same timestamp (up to 10 minutes precision)
      if (!memories
          .any((memory) => memory.timestamp == currentMemory.timestamp))
        memories.add(currentMemory);
    } catch (error) {
      log.warning("Failed to get hardware info");
      log.info(error.toString());
    }
  }
}

class Memory {
  int _timestamp = 0;
  int get timestamp => _timestamp;

  //info about RAM in bytes
  int _totalMemory = 0;
  int get totalMemory => _totalMemory;

  int _freeMemory = 0;
  int get freeMemory => _freeMemory;

  int get usedMemory => totalMemory - freeMemory;

  //info about RAM + SWAP file in bytes
  int _totalVirtualMemory = 0;
  int get totalVirtualMemory => _totalVirtualMemory;

  int _freeVirtualMemory = 0;
  int get freeVirtualMemory => _freeVirtualMemory;

  int get usedVirtualMemory => totalVirtualMemory - freeVirtualMemory;

  Memory(this._totalMemory, this._freeMemory, this._totalVirtualMemory,
      this._freeVirtualMemory) {
    //divides timestamp in segments of 10 minutes
    _timestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000 / 60 / 10).round() *
            1000 *
            60 *
            10;
  }

  toJson() => {
        "total": totalMemory,
        "free": freeMemory,
        "totalVirtual": totalVirtualMemory,
        "freeVirtual": freeVirtualMemory
      };

  Memory.fromJson(dynamic json) {
    if (json['total'] != null) _totalMemory = json['total'];
    if (json['free'] != null) _freeMemory = json['free'];
    if (json['totalVirtual'] != null)
      _totalVirtualMemory = json['totalVirtual'];
    if (json['freeVirtual'] != null) _freeVirtualMemory = json['freeVirtual'];
  }
}

class CPU {
  int _socket = 0;
  int get socket => _socket;

  int _threads = 0;
  int get threads => _threads;

  String _name = "N/A";
  String get name => _name;

  String _arch = "N/A";
  String get arch => _arch;

  CPU(this._socket, this._name, this._threads, this._arch);

  toJson() =>
      {"socket": socket, "threads": threads, "name": name, "arch": arch};

  CPU.fromJson(dynamic json) {
    if (json['socket'] != null) _socket = json['socket'];
    if (json['threads'] != null) _threads = json['threads'];
    if (json['name'] != null) _name = json['name'];
    if (json['arch'] != null) _arch = json['arch'];
  }
}
