import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) => writeResponseData(
    data,
    destinationDirectory:
        Platform.environment['PERF_OUTPUT_DIR'] ?? 'build/phone-performance',
    testOutputFilename:
        Platform.environment['PERF_RUN_NAME'] ?? 'phone-results',
  ),
);
