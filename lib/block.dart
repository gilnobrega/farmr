//this class contains data about won blocks
//can be extended to other info in the future
class Block {
  final int? height; // block height
  final int? timestamp; //block timestamp, THIS IS IN SECONDS
  String? plotPublicKey; //public key of plot which won block

  Block({this.height, this.timestamp, this.plotPublicKey});

  Block.fromJson(dynamic json)
      : this(
            height: json['height'],
            timestamp: json['timestamp'],
            plotPublicKey: json['plotPublicKey']);

  Map<String, dynamic> toJson() => {
        "height": height,
        "timestamp": timestamp,
        "plotPublicKey": plotPublicKey
      };
}
