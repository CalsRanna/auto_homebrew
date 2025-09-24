import 'package:args/command_runner.dart';
import 'package:tapster/commands/tap/create_command.dart';
import 'package:tapster/commands/tap/list_command.dart';
import 'package:tapster/commands/tap/update_command.dart';

class TapCommand extends Command {
  @override
  final name = 'tap';

  @override
  final description = 'Manage Homebrew tap repository';

  TapCommand() {
    addSubcommand(CreateCommand());
    addSubcommand(ListCommand());
    addSubcommand(UpdateCommand());
  }
}