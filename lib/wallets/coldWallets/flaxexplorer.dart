import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:farmr_client/wallets/localWallets/localWallet.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Chia Explorer Cold Wallet");

class FlaxExplorerWallet extends ColdWallet {
  FlaxExplorerWallet(
      {int netBalance = -1,
      int farmedBalance = -1,
      required Blockchain blockchain})
      : super(
            netBalance: netBalance,
            farmedBalance: farmedBalance,
            blockchain: blockchain);

  Future<void> init(String publicAddress, LocalWallet mainWallet) async {
    const String flaxExplorerURL =
        "https://flaxexplorer.org/blockchain/address/";
    //flaxexplorer has no way to know if wallet is empty or address invalid
    // always start with net balance and farm balances 0
    netBalance = 0;
    farmedBalance = 0;

    try {
      String contents =
          await http.read(Uri.parse(flaxExplorerURL + publicAddress));

      RegExp regex = RegExp(r"([0-9]+\.[0-9]+) XFX</span>", multiLine: true);

      try {
        var matches = regex.allMatches(contents);

        if (matches.length == 2) {
          netBalance =
              ((double.tryParse(matches.elementAt(0).group(1) ?? "-1.0") ??
                          -1.0) *
                      blockchain.majorToMinorMultiplier)
                  .round();
          farmedBalance =
              ((double.tryParse(matches.elementAt(1).group(1) ?? "-1.0") ??
                          -1.0) *
                      blockchain.majorToMinorMultiplier)
                  .round();
        }
      } catch (error) {
        log.warning("Failed to get info about flax cold wallet balance");
      }

      //tries to parse last farmed  reward
      RegExp blockHeightExp = RegExp(
          r'farmer reward<\/td>[\s]+<td><a href="\/blockchain\/coin\/[\w]+">[\w]+<\/a><\/td>[\s]+<td>[0-9\.]+ xfx<\/td>[\s]+<td>([0-9]+)',
          multiLine: true);

      try {
        var blockHeightMatches =
            blockHeightExp.allMatches(contents.toLowerCase());
        if (blockHeightMatches.length > 0)
          mainWallet.setLastBlockFarmed(
              int.parse(blockHeightMatches.first.group(1) ?? "-1"));
      } catch (error) {
        log.warning("Failed to get info about cold wallet last farmed reward");
      }
    } catch (error) {
      log.warning("Failed to get info about flax cold wallet");
    }
  }
}
