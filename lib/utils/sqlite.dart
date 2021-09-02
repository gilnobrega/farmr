import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:ffi';
import 'dart:io' as io;

Database openSQLiteDB(String dbPath, OpenMode mode) {
  late final Database db;

  try {
    db = sqlite3.open(dbPath, mode: mode);
  } catch (error) {
    open.overrideFor(
        OperatingSystem.linux, _openOnLinux); //provides .so file to linux
    open.overrideFor(OperatingSystem.windows,
        _openOnWindows); // provides .dll file to windows
    db = sqlite3.open(dbPath, mode: mode);
  }

  return db;
}

DynamicLibrary _openOnLinux() {
  final String scriptDir =
      io.File(io.Platform.script.toFilePath()).parent.path + "/";

  var libraryNextToScript;

  if (io.File("/etc/farmr/libsqlite3.so").existsSync())
    libraryNextToScript = io.File("/etc/farmr/libsqlite3.so");
  else
    libraryNextToScript = io.File(scriptDir + 'libsqlite3.so');

  return DynamicLibrary.open(libraryNextToScript.path);
}

DynamicLibrary _openOnWindows() {
  final scriptDir = io.File(io.Platform.script.toFilePath()).parent;

  final libraryNextToScript = io.File(scriptDir.path + '/sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}

int? coinbaseParentHeight(String input) {
  final String hex = input.substring(32);
  return int.tryParse("0x$hex");
}
