// Simple logging helpers. Can be replaced by a proper logging package later.
// Provides minimal levels and optional stack trace printing.

import 'dart:developer' as dev;

void logInfo(String message) {
  dev.log(message, name: 'INFO');
}

void logWarn(String message) {
  dev.log(message, name: 'WARN');
}

void logError(String message, [Object? errorOrStack]) {
  // Preserve existing call sites: the optional argument may be an error object OR a StackTrace.
  final Object? error = errorOrStack is StackTrace ? null : errorOrStack;
  final StackTrace? stack = errorOrStack is StackTrace ? errorOrStack : null;
  dev.log(message, name: 'ERROR', error: error, stackTrace: stack);
}
