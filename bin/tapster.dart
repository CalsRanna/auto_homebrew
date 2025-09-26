import 'dart:io';
import 'package:ansix/ansix.dart';
import 'package:args/command_runner.dart';
import 'package:tapster/commands/publish_command.dart';
import 'package:tapster/commands/init_command.dart';
import 'package:tapster/commands/doctor_command.dart';
import 'package:tapster/utils/status_markers.dart';

void main(List<String> arguments) async {
  final runner = CommandRunner('tapster', 'Homebrew Package Publishing Automation Tool')
    ..addCommand(PublishCommand())
    ..addCommand(InitCommand())
    ..addCommand(DoctorCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (error) {
    // CommandRunner automatically formats and displays help for usage errors
    print(error);
    exit(64); // Exit code 64 indicates a usage error
  } catch (error) {
    final buffer = StringBuffer()
      ..writeWithForegroundColor('${StatusMarker.error} ', AnsiColor.red)
      ..write('Error: $error');
    print(buffer.toString());
    exit(1);
  }
}