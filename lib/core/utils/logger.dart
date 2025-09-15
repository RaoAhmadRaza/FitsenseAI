// Simple logging helpers. Can be replaced by a proper logging package later.
// Provides minimal levels and optional stack trace printing.

import 'dart:developer' as dev;

void logInfo(String message) {
  dev.log(message, name: 'INFO');
}

void logWarn(String message) {
  dev.log(message, name: 'WARN');
}

void logError(String message, [Object? stack]) {
  dev.log(
    message,
    name: 'ERROR',
    error: message,
    stackTrace: stack is StackTrace ? stack : null,
  );
}
