import 'package:fclone/fclone.dart';

Future<void> main(List<String> arguments) async {
  await FClone.instance.runAll(arguments);
}