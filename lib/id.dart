import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;
import 'package:uuid/uuid.dart';

import 'package:logging/logging.dart';

Logger log = Logger("ID");

class ID {
  List<String> ids = [];

  late io.File _idFile;

  Map toJson() => {"ids": ids};

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
      _idFile.writeAsStringSync(jsonEncode(this));
    } catch (error) {
      log.warning("Failed to save id.json file");
    }
  }

  void info(List<Blockchain> blockchains) {
    List<String> idsWithBlockchains = [];

    for (Blockchain blockchain in blockchains) {
      //Appends blockchain symbol to id if there is more than one blockchain
      String idExtension =
          (blockchains.length == 1) ? "" : blockchain.fileExtension;

      for (String id in ids) idsWithBlockchains.add(id + idExtension);
    }
    print("");

    String line = "============================================";

    print(line);

    String instructions =
        "visit https://farmr.net to add it to your account.\nAlternatively, you can also link it through farmrbot (a discord bot) by running the following command:";
    print("");

    if (idsWithBlockchains.length > 1)
      log.warning(
          "Your ids are " + idsWithBlockchains.toString() + ", $instructions");
    else
      log.warning("Your id is " + idsWithBlockchains[0] + ", $instructions" "");

    print("");

    for (String idWithBlockchain in idsWithBlockchains)
      print("!chia link " + idWithBlockchain);

    print("");

    if (idsWithBlockchains.length > 1)
      print("To link this client to each discord user (one id per user)");
    else
      print("to link this client to your discord user");

    print("""You can interact with farmrbot in Swar's Chia Community
Open the following link to join the server: https://discord.gg/swar""");

    print("");
    print(line);
  }
}
