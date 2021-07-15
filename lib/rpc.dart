import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/id.dart';
import 'package:universal_io/io.dart';

enum RPCService { Daemon, Wallet, Farmer, Harvester, Full_Node }

//accepts self signed certificates
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class RPCPorts {
  late Map<RPCService, int?> _servicePorts;

  int? harvesterPort;
  int? walletPort;
  int? farmerPort;
  int? daemonPort;
  int? fullNodePort;

  Map toJson() => {
        "harvester": harvesterPort,
        "farmer": farmerPort,
        "wallet": walletPort,
        "full_node": fullNodePort,
        "daemon": daemonPort
      };

  _initializeServicePorts() {
    _servicePorts = {
      RPCService.Daemon: daemonPort,
      RPCService.Farmer: farmerPort,
      RPCService.Harvester: harvesterPort,
      RPCService.Wallet: walletPort,
      RPCService.Full_Node: fullNodePort
    };
  }

  RPCPorts(
      {required this.harvesterPort,
      required this.farmerPort,
      required this.walletPort,
      required this.fullNodePort,
      required this.daemonPort}) {
    _initializeServicePorts();
  }

  RPCPorts.fromJson(dynamic json) {
    harvesterPort = json['harvester'];
    farmerPort = json['farmer'];
    walletPort = json['wallet'];
    fullNodePort = json['fullNode'];
    daemonPort = json['daemon'];
    _initializeServicePorts();
  }

  int getServicePort(RPCService service) {
    return _servicePorts[service] ?? -1;
  }
}

main() async {
  Blockchain blockchain = Blockchain(ID(""), "", [], {});

  RPCConfiguration rpcConfig = RPCConfiguration(
      blockchain: blockchain,
      service: RPCService.Wallet,
      endpoint: "get_wallet_balance",
      dataToSend: {"wallet_id": 1});

  print(await RPCConnection.getEndpoint(rpcConfig: rpcConfig));
}

class RPCConfiguration {
  RPCService service;
  String endpoint;
  dynamic dataToSend;
  Blockchain blockchain;

  RPCConfiguration(
      {required this.blockchain,
      required this.service,
      required this.endpoint,
      required this.dataToSend});
}

class RPCConnection {
  static String getServiceName(RPCService service) {
    return service.toString().split('.')[1].toLowerCase();
  }

  static Future<dynamic> getEndpoint(
      {required RPCConfiguration rpcConfig}) async {
    HttpOverrides.global = MyHttpOverrides();

    String serviceName = getServiceName(rpcConfig.service);
    print(serviceName);
    String certFile = rpcConfig.blockchain.configPath +
        "/ssl/$serviceName/private_$serviceName.crt";
    print(certFile);
    String privateKey = rpcConfig.blockchain.configPath +
        "/ssl/$serviceName/private_$serviceName.key";
    print(privateKey);

    var context = SecurityContext.defaultContext;
    context.useCertificateChain(certFile);
    context.usePrivateKey(privateKey);
    HttpClient client = new HttpClient(context: context);

    //reads service port
    int port = rpcConfig.blockchain.rpcPorts!.getServicePort(rpcConfig.service);
    // The rest of this code comes from your question.
    var uri = "https://localhost:$port/$endpoint";
    print(uri);
    var data = jsonEncode(rpcConfig.dataToSend);
    print(data);
    var method = 'POST';

    var request = await client.openUrl(method, Uri.parse(uri));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(data);
    var response = await request.close();

    return jsonDecode(await response.transform(Utf8Decoder()).join(''));
    // Process the response.
  }
}
