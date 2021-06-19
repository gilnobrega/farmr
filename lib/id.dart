import 'dart:convert';

import 'package:universal_io/io.dart' as io;
import 'package:uuid/uuid.dart';

import 'package:logging/logging.dart';

Logger log = Logger("ID");

class ID {
  List<String> ids = [];

  late io.File _idFile;

  ID(String rootPath) {
    //initializes array with 1 id
    ids = [Uuid().v4()];

    _idFile = io.File(rootPath + "id.json");
  }

  Future<void> init() async {
    //Loads id file
    if (!_idFile.existsSync())
      save(); //creates id file if doesnt exist
    else {
      load(); //id.json
    }
  }

  void load() {
    try {
      var json = jsonDecode(_idFile.readAsStringSync());

      //loads ids from json object
      if (json['ids'] != null) {
        ids = [];
        for (String id in json['ids']) ids.add(id);
      }
    } catch (error) {
      log.warning("Failed to load id.json file.\nGenerating a new ID");
    }
  }

  void save() {
    try {
      _idFile.writeAsStringSync(this.toJson());
    } catch (error) {
      log.warning("Failed to save id.json file");
    }
  }

  toJson() => {"ids", ids};
}
