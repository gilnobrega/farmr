import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;
import 'package:uuid/uuid.dart';

import 'package:logging/logging.dart';

import 'package:http/http.dart' as http;

Logger log = Logger("ID");

class ID {
  String? sponsoredMessage;

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

  Future<String> info(List<Blockchain> blockchains) async {
    String output = "";
    List<String> idsWithBlockchains = [];

    for (Blockchain blockchain in blockchains) {
      //Appends blockchain symbol to id
      for (String id in ids)
        idsWithBlockchains.add(id + blockchain.fileExtension);
    }
    output += "\n";
    String line = "============================================";

    output += "\n$line";

    String instructions =
        "visit https://farmr.net to add it to your account.\nAlternatively, you can also link it through farmrbot (a discord bot) by running the following command:";
    output += "\n";

    if (idsWithBlockchains.length > 1)
      output +=
          "\nYour ids are " + idsWithBlockchains.toString() + ", $instructions";
    else
      output += "\nYour id is " + idsWithBlockchains[0] + ", $instructions";

    output += "\n";

    for (String idWithBlockchain in idsWithBlockchains)
      output += "\n!chia link " + idWithBlockchain;

    output += "\n";

    if (idsWithBlockchains.length > 1)
      output += "\nTo link this client to each discord user (one id per user)";
    else
      output += "\nto link this client to your discord user";

    output +=
        """\nYou can interact with farmrbot in Swar's Chia Community
Open the following link to join the server: https://discord.gg/fghFbffYsC""";

    output += "\n";
    output += "\n$line";

    output += await showSponsor();

    return output;
  }

  //reads sponsor from farmr.net
  Future<String> showSponsor() async {
    String output = "\n";

    try {
      if (sponsoredMessage == null) {
        const String sponsorUrl = r"https://farmr.net/sponsor.txt";

        sponsoredMessage = (await http.get(Uri.parse(sponsorUrl))).body;
      }

      output += "\n" + (sponsoredMessage ?? "");
    } catch (error) {}

    return output;
  }
}
