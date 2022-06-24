import 'package:sqlite3/sqlite3.dart';

Database openSQLiteDB(String dbPath, OpenMode mode) {
  return sqlite3.open(dbPath, mode: mode);
}

int? coinbaseParentHeight(String input) {
  final String hex = input.substring(32);
  return int.tryParse("0x$hex");
}
