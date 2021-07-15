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

  RPCPorts(
      {required this.harvesterPort,
      required this.farmerPort,
      required this.walletPort,
      required this.fullNodePort,
      required this.daemonPort}) {
    _servicePorts = {
      RPCService.Daemon: daemonPort,
      RPCService.Farmer: farmerPort,
      RPCService.Harvester: harvesterPort,
      RPCService.Wallet: walletPort,
      RPCService.Full_Node: fullNodePort
    };
  }

  RPCPorts.fromJson(dynamic json) {
    harvesterPort = json['harvester'];
    farmerPort = json['farmer'];
    walletPort = json['wallet'];
    fullNodePort = json['fullNode'];
    daemonPort = json['daemon'];
  }

  int getServicePort(RPCService service) {
    return _servicePorts[service] ?? -1;
  }
}

main() async {
  Blockchain blockchain = Blockchain(ID(""), "", [], {});
  RPC rpc = RPC(blockchain);

  print(await rpc
      .getEndpoint(RPCService.Wallet, "get_wallet_balance", {"wallet_id": 1}));
  print(await rpc.getEndpoint(
    RPCService.Wallet,
    "get_plots",
    {},
  ));
}

class RPC {
  Blockchain _blockchain;

  RPC(this._blockchain);

  static String getServiceName(RPCService service) {
    return service.toString().split('.')[1].toLowerCase();
  }

  Future<dynamic> getEndpoint(
      RPCService service, String endpoint, dynamic dataToSend) async {
    HttpOverrides.global = MyHttpOverrides();

    String serviceName = getServiceName(service);
    print(serviceName);
    String certFile =
        _blockchain.configPath + "/ssl/$serviceName/private_$serviceName.crt";
    print(certFile);
    String privateKey =
        _blockchain.configPath + "/ssl/$serviceName/private_$serviceName.key";
    print(privateKey);

    var context = SecurityContext.defaultContext;
    context.useCertificateChain(certFile);
    context.usePrivateKey(privateKey);
    HttpClient client = new HttpClient(context: context);

    //reads service port
    int port = _blockchain.rpcPorts!.getServicePort(service);
    // The rest of this code comes from your question.
    var uri = "https://localhost:$port/$endpoint";
    print(uri);
    var data = jsonEncode(dataToSend);
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
