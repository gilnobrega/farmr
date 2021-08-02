import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/rpc.dart';
import 'package:proper_filesize/proper_filesize.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

import 'package:http/http.dart' as http;

//connection in chia show -c
class Connection {
  //type of connection
  final ConnectionType type;

  //ip from connection e.g. 127.0.0.1
  final String ip;

  //ports associated with connection e.g. 8444/8444
  final List<int?> ports;

  final int? peakHeight;

  final int? bytesRead;
  final int? bytesWritten;
  String get bytesReadString =>
      ProperFilesize.generateHumanReadableFilesize(bytesRead?.toDouble() ?? 0);
  String get bytesWrittenString =>
      ProperFilesize.generateHumanReadableFilesize(bytesRead?.toDouble() ?? 0);

  Country? country;

  Connection(
      {required this.type,
      required this.ip,
      required this.ports,
      this.peakHeight,
      this.bytesRead,
      this.bytesWritten,
      this.country});

  Map toJson() => {
        "type": type.index,
        "ip": ip,
        "ports": ports,
        "peakHeight": peakHeight,
        "bytesRead": bytesRead,
        "bytesWritten": bytesWritten,
        "country": country
      };
}

//Maybe there are more???
enum ConnectionType {
  ERROR,
  FullNode,
  Harvester,
  Farmer,
  Timelord,
  Introducer,
  Wallet,
}

final log = Logger('FarmerWallet');

class Connections {
  final List<Connection> connections;

  Connections(this.connections);

  static Future<Connections> generateConnections(Blockchain blockchain) async {
    List<Connection> connections = [];

    final bool? isFullNodeRunning = ((await blockchain.rpcPorts
            ?.isServiceRunning([RPCService.Full_Node])) ??
        {})[RPCService.Full_Node];

    //checks if full node rpc ports are defined
    if (isFullNodeRunning ?? false) {
      RPCConfiguration configuration = RPCConfiguration(
          blockchain: blockchain,
          service: RPCService.Full_Node,
          endpoint: "get_connections");

      final response = await RPCConnection.getEndpoint(configuration);

      if (response['success'] ?? false) {
        final connectionsList = response['connections'];

        for (var connection in connectionsList) {
          ConnectionType type =
              ConnectionType.values[(connection['type'] ?? 0)];

          connections.add(Connection(
              type: type,
              ip: connection['peer_host'],
              ports: [connection['local_port'], connection['peer_server_port']],
              peakHeight: connection['peak_height'],
              bytesRead: connection['bytes_read'],
              bytesWritten: connection['bytes_written']));
        }
      }

      //print(jsonEncode(connections));
      //io.stdin.readLineSync(); //debug
    }
    //if not parses connections in legacy mode
    else {
      var connectionsOutput = io.Process.runSync(
              blockchain.config.cache!.binPath, const ["show", "-c"])
          .stdout
          .toString();

      try {
        RegExp connectionsRegex = RegExp(
            "([\\S_]+) ([\\S\\.]+)[\\s]+([0-9]+)/([0-9]+)",
            multiLine: true);

        var matches = connectionsRegex.allMatches(connectionsOutput);

        for (var match in matches) {
          try {
            var typeString = match.group(1);
            final ConnectionType type;

            if (typeString == "FULL_NODE")
              type = ConnectionType.FullNode;
            else if (typeString == "INTRODUCER")
              type = ConnectionType.Introducer;
            else if (typeString == "WALLET")
              type = ConnectionType.Wallet;
            else if (typeString == "FARMER")
              type = ConnectionType.Farmer;
            else
              type = ConnectionType.ERROR;

            String ip = match.group(2) ?? 'N/A';
            int port1 = int.parse(match.group(3) ?? '-1');
            int port2 = int.parse(match.group(4) ?? '-1');

            Connection connection =
                new Connection(type: type, ip: ip, ports: [port1, port2]);

            connections.add(connection);
          } catch (e) {
            log.warning("Failed to parse connection");
          }
        }
      } catch (e) {
        log.warning("Failed to parse connections");
      }
    }

    return Connections(connections);
  }

  Future<void> getCountryCodes() async {
    http.Response response = await http.post(
        Uri.parse("http://ip-api.com/batch"),
        body: jsonEncode(connections.map((e) => e.ip).toList()));

    var responseObject = jsonDecode(response.body);

    for (var countryObject in responseObject) {
      final String ip = countryObject['query'] ?? "N/A";

      final String countryName = countryObject['country'] ?? "N/A";
      final String countryCode = countryObject['countryCode'] ?? "N/A";

      for (int i = 0; i < connections.length; i++) {
        Connection connection = connections[i];

        if (connection.ip == ip)
          connection.country = Country(code: countryCode, name: countryName);
      }
    }

    print(jsonEncode(connections));
    io.stdin.readByteSync(); //debug
  }
}

class Country {
  final String code;
  final String name;

  const Country({required this.code, required this.name});

  Map toJson() => {'code': code, 'name': name};
}
