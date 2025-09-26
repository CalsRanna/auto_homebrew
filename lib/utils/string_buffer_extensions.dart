import 'package:ansix/ansix.dart';
import 'package:tapster/utils/status_markers.dart';

/// Extensions for StringBuffer to simplify writing colored status messages
extension StringBufferExtensions on StringBuffer {
  /// Write a success message with the success marker in green
  void writeSuccess(String text) {
    writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green);
    write(text);
  }

  /// Write an error message with the error marker in red
  void writeError(String text) {
    writeWithForegroundColor('${StatusMarker.error} ', AnsiColor.red);
    write(text);
  }

  /// Write a warning message with the warning marker in yellow
  void writeWarning(String text) {
    writeWithForegroundColor('${StatusMarker.warning} ', AnsiColor.yellow1);
    write(text);
  }

  /// Write a bullet point in green (for success details)
  void writeBullet(String text) {
    writeWithForegroundColor('${StatusMarker.bullet} ', AnsiColor.green);
    write(text);
  }

  /// Write a success bullet (✓) in green
  void writeSuccessBullet(String text) {
    writeWithForegroundColor('${StatusMarker.successBullet} ', AnsiColor.green);
    write(text);
  }

  /// Write an error bullet (✗) in red
  void writeErrorBullet(String text) {
    writeWithForegroundColor('${StatusMarker.errorBullet} ', AnsiColor.red);
    write(text);
  }

  /// Write a warning bullet (!) in yellow
  void writeWarningBullet(String text) {
    writeWithForegroundColor(
      '${StatusMarker.warningBullet} ',
      AnsiColor.yellow1,
    );
    write(text);
  }

  /// Write gray default value text (for input prompts)
  void writeGreyDefault(String text) {
    writeWithForegroundColor(text, AnsiColor.grey50);
  }
}
