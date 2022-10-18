library fclone;

import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

/// A Calculator.
class FClone {
  String? path;
  static FClone? _instance;

  FClone._internal();

  static FClone get instance => _getInstance();

  static FClone _getInstance() {
    _instance ??= FClone._internal();
    return _instance!;
  }

  void exec(List<String> arguments) {
    loadKeys(arguments);
  }

  Future<void> loadKeys(List<String> arguments) async {
    if (arguments.isEmpty) {
      final parsedArgs = loadConfigFile();
      path = parsedArgs['path'];
    } else {
      final parser = ArgParser();
      parser.addOption('path');
      final parsedArgs = parser.parse(arguments);
      path = parsedArgs['path'];
    }
    if (path == null) {
      flog(
          'error path not found please specify path where you store your zip file');
    } else {
      if (Uri.parse(path!).isAbsolute) {
        flog('path is a url will download zip...');
      } else {
        File file = File(path!);
        if (!await file.exists()) {
          flog('error path not found $path');
        }
      }
    }
  }

  Map<String, String> loadConfigFile() {
    final File file = File('pubspec.yaml');
    final String yamlString = file.readAsStringSync();
    final Map yamlMap = loadYaml(yamlString);

    if (yamlMap['fclone'] is! Map) {
      throw Exception('fclone was not found');
    }
    final Map<String, String> config = <String, String>{};
    for (MapEntry<dynamic, dynamic> entry in yamlMap['fclone'].entries) {
      config[entry.key] = entry.value.toString();
    }

    return config;
  }

  flog(String s) {
    print('FCLONE :: $s');
  }
}
