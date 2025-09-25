import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:tapster/commands/publish_command.dart';
import 'package:tapster/commands/init_command.dart';
import 'package:tapster/commands/tap_command.dart';
import 'package:tapster/commands/formula_command.dart';
import 'package:tapster/commands/wizard_command.dart';
import 'package:tapster/commands/doctor_command.dart';

void main(List<String> arguments) async {
  final runner = CommandRunner('tapster', 'Homebrew Package Publishing Automation Tool')
    ..addCommand(PublishCommand())
    ..addCommand(InitCommand())
    ..addCommand(TapCommand())
    ..addCommand(FormulaCommand())
    ..addCommand(WizardCommand())
    ..addCommand(DoctorCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (error) {
    // CommandRunner automatically formats and displays help for usage errors
    print(error);
    exit(64); // Exit code 64 indicates a usage error
  } catch (error) {
    print('Error: $error');
    exit(1);
  }
}