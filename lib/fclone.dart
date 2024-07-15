library fclone;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:flutter_native_splash/cli_commands.dart';
import 'package:flutter_platform_versioning/flutter_platform_versioning.dart'
    as flutter_platform_versioning;
import 'package:http/http.dart';
import 'package:icons_launcher/cli_commands.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:package_rename/package_rename.dart' as package_rename;
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

/// A Calculator.
class FClone {
  String? zipFile;
  String? zipDir;
  List<String>? pathList;
  String? backupName;
  Map<String, dynamic> dataPrevConst={};
  static FClone? _instance;

  FClone._internal();

  static FClone get instance => _getInstance();

  static FClone _getInstance() {
    _instance ??= FClone._internal();
    return _instance!;
  }

  List<String> impFiles = [
    'package_rename_config.json',
    'icons_launcher.json',
    'flutter_native_splash.json',
    'flutter_platform_versioning.json',
    'fclone.json',
  ];
  String fcloneConstants = 'fclone_constants.json';
  String fcloneReplaceFile = 'fclone_replace_file.json';

  Future<void> runAll(List<String> arguments) async {
    await loadKeys(arguments);
  }
  //
  // Future<void> exec(List<String> arguments) async {
  //   await loadKeys(arguments);
  //   await generate();
  // }
  //
  // Future<void> backup(List<String> arguments) async {
  //   await loadKeys(arguments);
  //   await backupAll();
  // }
  //
  // Future<void> run(List<String> arguments) async {
  //   await loadKeys(arguments);
  //   for (var element in impFiles) {
  //     await runYamlFile(element.toString().replaceAll('.json', ''));
  //   }
  //   if (await Directory('${backupName}_fclone').exists()) {
  //     await Directory('${backupName}_fclone').delete(recursive: true);
  //   }
  // }

  Future<Map<String, dynamic>> _configFileExists() async {
    final configFile = File('fclone.yaml');
    final pubspecFile = File('pubspec.yaml');
    if (await configFile.exists()) {
      return await loadConfigFile('fclone.yaml');
    } else if (await pubspecFile.exists()) {
      return await loadConfigFile('pubspec.yaml');
    } else {
      throw "File Not Found !! make sure you have fclone.yaml or pubspec.yaml in your path";
    }
  }

  Future<void> loadKeys(List<String> arguments) async {
    final parser = ArgParser();
    parser.addFlag(
      'backup',
      negatable: false,
      help: 'Backup current project with fclone.',
    );
    parser.addFlag(
      'generate',
      negatable: false,
      help: "This will generate files from url or path to process cloning.",
    );
    parser.addFlag(
      'clone',
      negatable: false,
      help: 'To clone project with provided fclone file or path.',
    );
    parser.addFlag(
      'all',
      negatable: false,
      help: 'It will do all above 3 at once.',
    );
    parser.addOption('zip_file',
        abbr: 'f',
        help: "This should be a path or a link of fclone zip file.");
    parser.addOption('zip_dir',
        abbr: 'd', help: "This should be a directory path for fclone folder.");
    parser.addOption('backup_name',
        abbr: 'n',
        help:
            "This is the name of the backup it will automatically add date and time and _fclone in the end.");
    parser.addMultiOption('backup_paths',
        abbr: 'p',
        help:
            "This is list of paths of files or directory which will add to fclone file for backup.");
    parser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Prints out available command usages',
    );
    final parsedArgs = parser.parse(arguments);

    if (parsedArgs.wasParsed('help') || parsedArgs.arguments.isEmpty) {
      flog("\n${parser.usage}");
    }

    if (parsedArgs['backup_paths'] is List) {
      pathList = parsedArgs['backup_paths'];
    }
    zipFile = parsedArgs['zip_file'];
    zipDir = parsedArgs['zip_dir'];
    backupName = parsedArgs['backup_name'];

    var parsedArgsConfig = await _configFileExists();
    if (parsedArgsConfig.isNotEmpty) {
      if ((zipFile ?? '').isEmpty) {
        zipFile = parsedArgsConfig['zip_file'];
      }
      if ((zipDir ?? '').isEmpty) {
        zipDir = parsedArgsConfig['zip_dir'];
      }
      if ((backupName ?? '').isEmpty) {
        backupName = parsedArgsConfig['backup_name'];
      }
      if ((pathList ?? []).isEmpty) {
        if (parsedArgsConfig['backup_paths'] is List) {
          pathList = List<String>.from(
              (parsedArgsConfig['backup_paths'] as YamlList)
                  .value
                  .map((e) => e.toString()));
        }
      }
    }

    if (parsedArgs.wasParsed('backup') || parsedArgs.wasParsed('all')) {
      await backupAll();
      flog("Successfully Backup !!");
    }
    if (parsedArgs.wasParsed('generate') || parsedArgs.wasParsed('all')) {
      await generate();
      flog("Successfully Generate !!");
    }
    if (parsedArgs.wasParsed('clone') || parsedArgs.wasParsed('all')) {
      for (var element in impFiles) {
        try {
          await runYamlFile(element.toString().replaceAll('.json', ''));
        }catch(e){
          flog("EROOR ::  $e");
        }
      }
      if (await Directory('${backupName}_fclone').exists()) {
        await Directory('${backupName}_fclone').delete(recursive: true);
      }
      flog("Successfully Clone !!");
    }
  }

  Future<void> generate() async {
    if (zipFile == null) {
      flog(
          'Error path not found please specify path where you store your zip file');
    } else {
      if (Uri.parse(zipFile!).isAbsolute) {
        flog('path is a url will download zip...');
        await getZipFromUrl(zipFile!);
      } else {
        File file = File(zipFile!);
        if (!await file.exists()) {
          flog('error path not found $zipFile');
        } else {
          await generateFiles(file);
        }
      }
    }
  }

  Future<Map<String, dynamic>> loadConfigFile(String yamlFile) async {
    final File file = File(yamlFile);
    final String yamlString = await file.readAsString();
    final Map yamlMap = loadYaml(yamlString);
    if (yamlMap['fclone'] is! Map) {
      throw Exception('fclone was not found');
    }
    final Map<String, dynamic> config = <String, dynamic>{};
    for (MapEntry<dynamic, dynamic> entry in yamlMap['fclone'].entries) {
      config[entry.key] =
          (entry.value is List) ? entry.value : entry.value.toString();
    }

    return config;
  }

  flog(String s) {
    print('FCLONE :: $s');
  }

  Future<void> generateFiles(File file) async {
    Directory directory;
    dataPrevConst = await backupConstantClass();

    if (zipDir == null || zipDir!.isEmpty) {
      directory = Directory('${backupName ?? ''}_fclone');

      ///unarchive zip file...
      try {
//       final bytes = await File(file.path).readAsBytes();
//       final archive = ZipDecoder().decodeBytes(bytes);
        final bytes = File(file.path).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        await Future.forEach<ArchiveFile>(archive.files, (file) async {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            File file3 = await File('${directory.path}/$filename')
                .create(recursive: true);
            await file3.writeAsBytes(data);
            // ..createSync(recursive: true)
            // ..writeAsBytesSync(data);
          } else {
            await Directory('${directory.path}/$filename')
                .create(recursive: true);
          }
        });
        // final inputStream = InputFileStream(file.path);
        // final archive = ZipDecoder().decodeBuffer(inputStream);
        // extractArchiveToDisk(archive, 'fclone');
      } catch (e) {
        flog('$e');
      }
    } else {
      directory = Directory(zipDir!);
    }

    /// working on consts ...
    File fcloneConsts = File('${directory.path}/$fcloneConstants');
    if (await fcloneConsts.exists()) {
      await generateConstantsFromJson(fcloneConsts);
    }

    /// working on file replacing if needed. like logos etc...
    File fcloneReplace = File('${directory.path}/$fcloneReplaceFile');
    if (await fcloneReplace.exists()) {
      await replaceFilesFromJson(fcloneReplace);
    }

    /// generate icon,name,splash screen files and run same time..
    await Future.forEach(impFiles, (element) async {
      File incoming = File('${directory.path}/$element');
      File outGoing = File(element.toString().replaceAll('.json', '.yaml'));
      if (await incoming.exists()) {
        if (await outGoing.exists()) {
          await outGoing.delete();
        }
        String data = json2yaml(jsonDecode(await incoming.readAsString()),
            yamlStyle: YamlStyle.pubspecYaml);
        RegExp regExp = RegExp("#(?:[0-9a-fA-F]{6})");
        data = data.replaceAllMapped(regExp, (match) {
          return '"${match.group(0)}"';
        });
        await outGoing.writeAsString(
          '# Generated By Bikramaditya From Fclone\n$data',
        );
        // await runYamlFile(element.toString().replaceAll('.json', ''));
      }
    });
  }

  Future<void> runYamlFile(String name) async {
    switch (name) {
      case 'package_rename_config':
        try {
          if (await File('package_rename_config.yaml').exists()) {
            package_rename.set([]);
          }
        } catch (e) {
          flog('error on package rename ::$e');
        }
        break;
      case 'icons_launcher':
        try {
          if (await File('icons_launcher.yaml').exists()) {
            createLauncherIcons(path: 'icons_launcher.yaml', flavor: null);
          }
        } catch (e) {
          flog('error on icon launcher :: $e');
        }
        break;
      case 'flutter_native_splash':
        try {
          if (await File('flutter_native_splash.yaml').exists()) {
            createSplash(
              path: 'flutter_native_splash.yaml',
              flavor: null,
            );
          }
        } catch (e) {
          flog('error on native splash :: $e');
        }
        break;
      case 'flutter_platform_versioning':
        try {
          if (await File('flutter_platform_versioning.yaml').exists()) {
            flutter_platform_versioning.set(['--update']);
          }
        } catch (e) {
          flog('error on package platform versioning ::$e');
        }
    }
  }

  Future<void> generateConstantsFromJson(File fcloneConsts) async {
    try {
      File fcloneFile =
          File('lib/${fcloneConstants.replaceAll('.json', '.dart')}');
      Map jsonData = jsonDecode(await fcloneConsts.readAsString());

      dataPrevConst.forEach((k,v){
        if(jsonData.containsKey(k)){
          if(v is List){
            (jsonData[k] as List).addAll(v);
           jsonData[k]= jsonData[k].toSet().toList();
          }
        }else{
          jsonData[k]=v;
        }
      });
      String data = '/// Generated By Bikramaditya From Fclone\n';
      if (jsonData.containsKey('import_fclone')) {
        List<String> imports = List<String>.from(jsonData['import_fclone']);
        for (var element in imports) {
          data += "$element\n";
        }
        jsonData.remove('import_fclone');
      }

      data += '\n\nclass FcloneConstants {\n\n';
      jsonData.forEach((key, value) {
        data += 'static var $key= $value ;\n';
      });
      data += '\n}';


      await fcloneFile.writeAsString(data);
    } catch (e) {
      flog('error on formatting constants :: $e');
    }
  }

  Future<void> replaceFilesFromJson(File fcloneReplace) async {
    try {
      Map jsonData = jsonDecode(await fcloneReplace.readAsString());
      await Future.forEach(jsonData.entries, (element) async {
        File file1 = File('${element.key}'); // old file
        File file2 = File('${element.value}'); // new file
        if (await file2.exists()) {
          if (await file1.exists()) {
            await file1.delete();
          }
          await file2.copy(file1.path);
        } else {
          flog('error file not found :: ${file2.path}');
        }
      });
    } catch (e) {
      flog('error on replacing files :: $e');
    }
  }

  Future<void> getZipFromUrl(String s) async {
    final request = Request('GET', Uri.parse(s));
    final StreamedResponse response = await Client().send(request);

    final contentLength = response.contentLength;
    // final contentLength = double.parse(response.headers['x-decompressed-content-length']);
    List<int> bytes = [];

    File file = File('fclone.zip');
    response.stream.listen(
      (List<int> newBytes) {
        bytes.addAll(newBytes);
        final downloadedLength = bytes.length;
        flog(
            'downloading ... :: ${(downloadedLength / (contentLength ?? 1)) * 100}');
      },
      onDone: () async {
        flog('downloaded');
        await file.writeAsBytes(bytes);
        await generateFiles(file);
      },
      onError: (e) {
        flog('error on downloading :: $e');
      },
      cancelOnError: true,
    );
  }

  Future<Map<String, dynamic>> backupConstantClass() async {
    Map<String, dynamic> data = {};
    File file = File('lib/${fcloneConstants.replaceAll('.json', '.dart')}');
    if (await file.exists()) {
      String constantString = await file.readAsString();
      RegExp regExp = RegExp("static var (.+?)=");
      regExp.allMatches(constantString).forEach((element) {
        data.addAll({"${element.group(1)}": ''});
      });
      // RegExp regExp2 = RegExp("= (\n|.)*?;", multiLine: true, dotAll: true);
      RegExp regExp2 = RegExp("=(\n|)(\n|.)*?;", multiLine: true, dotAll: true);
      // RegExp regExp2 = RegExp("= (\n|.+?)*?;");
      int f = 0;

      regExp2.allMatches(constantString).forEach((element) {
        try {
          data.addAll({
            data.keys.elementAt(f):
            element.group(0)!.replaceAll('=', '').replaceAll(';', ''),
          });
        } catch (e) {}
        f++;
      });
      RegExp regExp3 = RegExp("import (.+?);");
      if (!data.containsKey('import_fclone')) {
        data['import_fclone'] = [];
      }
      regExp3.allMatches(constantString).forEach((element) {
        data['import_fclone'].add(
          '${element.group(0)}',
        );
      });
    }
    return data;
  }

  Future<void> backupAll() async {
    Directory? directory = Directory('${backupName ?? ''}_fclone');

    if (!await directory.exists()) {
      directory.create();
    }

    /// backup icon,name,splash screen files and run same time..
    await Future.forEach(impFiles, (element) async {
      File incoming = File(element.toString().replaceAll('.json', '.yaml'));
      File outGoing = File('${directory.path}/$element');
      if (await incoming.exists()) {
        if (await outGoing.exists()) {
          await outGoing.delete();
        }
        await outGoing.create();
        final Map yamlMap = loadYaml(await incoming.readAsString());
        await outGoing.writeAsString(
          jsonEncode(yamlMap),
        );
      }
    });

    ///backup constant class
    File outGoing = File('${directory.path}/$fcloneConstants');
    if (await outGoing.exists()) {
      await outGoing.delete();
    }
    Map<String, dynamic> data = await backupConstantClass();
    await outGoing.writeAsString(jsonEncode(data));


    ///copy replaceable files
    if (pathList != null && pathList!.isNotEmpty) {
      File fileRel = File('${directory.path}/$fcloneReplaceFile');
      Directory replaceDirectory = Directory('${directory.path}/replace');
      if (!await replaceDirectory.exists()) {
        await replaceDirectory.create();
      }
      if (await fileRel.exists()) {
        await fileRel.delete();
      }
      Map<String, String> data = {};
      await Future.forEach<String>(pathList!, (element) async {
        FileSystemEntityType type = await FileSystemEntity.type(element);
        if (type == FileSystemEntityType.file) {
          File file = File(element);
          try {
            String name = basename(file.path);
            await file.copy('${replaceDirectory.path}/$name');
            data.addAll({
              element: '${replaceDirectory.path}/$name',
            });
          } catch (e) {
            flog('Error :  $e');
          }
        } else if (type == FileSystemEntityType.directory) {
          data.addAll(await filesInDirectory(
              Directory(element), replaceDirectory, data));
        }
      });
      await fileRel.writeAsString(jsonEncode(data));
    }

    /// create zip ..
    var encoder = ZipFileEncoder();
    encoder.create('${backupName ?? ''}_${DateTime.now()}_fclone.zip');
    await encoder.addDirectory(directory, includeDirName: false);
    encoder.close();
    await directory.delete(recursive: true);

  }

  Future<Map<String, String>> filesInDirectory(
      Directory dir, Directory repla, data) async {
    var dirList = dir.path.split('/');
    String dirstr = repla.path;
    await Future.forEach<String>(dirList, (element) async {
      dirstr = '$dirstr/$element';
      Directory rr2 = Directory(dirstr);
      if (!await rr2.exists()) {
        await rr2.create();
      }
    });

    var lister = await dir.list(recursive: false, followLinks: false).toList();
    await Future.forEach<FileSystemEntity>(lister, (entity) async {
      FileSystemEntityType type = await FileSystemEntity.type(entity.path);
      if (type == FileSystemEntityType.file) {
        try {
          File file = File(entity.uri.toString());
          await file.copy('${repla.path}/${file.path}');
          data.addAll({file.path: '${repla.path}/${file.path}'});
        } catch (e) {
          flog('Error :: $e');
        }
      } else if (type == FileSystemEntityType.directory) {
        Directory rr = Directory('${repla.path}/${entity.uri}');
        if (!await rr.exists()) {
          await rr.create();
        }
        await filesInDirectory(Directory(entity.uri.toString()), rr, data);
      }
    });
    return data;
  }
}
