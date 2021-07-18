import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Chia Explorer Cold Wallet");

class PosatIOWallet extends ColdWallet {
  PosatIOWallet({int netBalance = -1, required Blockchain blockchain})
      : super(netBalance: netBalance, blockchain: blockchain);

  Future<void> init() async {
    String posatExplorerURL =
        "https://${blockchain.binaryName}.posat.io/address/";

    netBalance = 0;

    try {
      String contents = await http.read(
          Uri.parse(posatExplorerURL + blockchain.config.coldWalletAddress));

      RegExp regex = RegExp(
          r"balance: <strong>([0-9]+\.[0-9]+) " +
              blockchain.currencySymbol.toUpperCase(),
          multiLine: true);

      try {
        var matches = regex.allMatches(contents.replaceAll(",", ""));

        if (matches.length > 0) {
          netBalance =
              ((double.tryParse(matches.elementAt(0).group(1) ?? "-1.0") ??
                          -1.0) *
                      blockchain.majorToMinorMultiplier)
                  .round();
        }
      } catch (error) {
        log.warning(
            "Failed to get info about ${blockchain.binaryName} cold wallet balance");
      }

      //tries to parse last farmed  reward
      RegExp blockHeightExp = RegExp(
          r'([0-9]+)<\/a><\/td>[\s]+<td><a href="\/coin\/[\w]+">[\w]+<\/a><\/td>[\s]+<td>farmer reward<\/td>[\s]+<td class="right">[0-9\.]+ ' +
              blockchain.currencySymbol.toLowerCase() +
              r'<\/td>',
          multiLine: true);

      try {
        var blockHeightMatches =
            blockHeightExp.allMatches(contents.toLowerCase());
        if (blockHeightMatches.length > 0)
          setLastBlockFarmed(
              int.parse(blockHeightMatches.first.group(1) ?? "-1"));
      } catch (error) {
        log.warning("Failed to get info about cold wallet last farmed reward");
      }
    } catch (error) {
      log.warning(
          "Failed to get info about ${blockchain.binaryName} cold wallet");
    }
  }
}
