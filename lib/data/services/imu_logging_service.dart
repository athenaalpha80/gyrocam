import 'dart:async';
import 'dart:io';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/recording_session_paths.dart';
import 'gyro_csv_formatter.dart';
import 'recording_storage_service.dart';

class ImuLoggingService {
  IOSink? _sink;
  Stopwatch? _stopwatch;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  AccelerometerEvent? _latestAccelerometer;

  bool get isRunning => _sink != null;

  Future<void> start({
    required RecordingSessionPaths paths,
    required int samplingRateHz,
    required String orientation,
  }) async {
    await stop();

    final logFile = File(paths.gcsvPath);
    await logFile.parent.create(recursive: true);
    _sink = logFile.openWrite(mode: FileMode.writeOnly);
    _sink!.write(
      GyroCsvFormatter.buildHeader(
        context: RecordingHeaderContext(
          videoFileName: paths.videoFileName,
          orientation: orientation,
          unixTimestampSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    );

    _stopwatch = Stopwatch()..start();
    final period = Duration(
      microseconds: (1000000 / samplingRateHz).round(),
    );

    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: period,
    ).listen((event) {
      _latestAccelerometer = event;
    });

    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: period,
    ).listen((event) {
      final sink = _sink;
      final stopwatch = _stopwatch;
      final accelerometer = _latestAccelerometer;
      if (sink == null || stopwatch == null || accelerometer == null) {
        return;
      }

      sink.writeln(
        GyroCsvFormatter.buildDataRow(
          elapsedMicros: stopwatch.elapsedMicroseconds,
          gx: event.x,
          gy: event.y,
          gz: event.z,
          axMetersPerSecondSquared: accelerometer.x,
          ayMetersPerSecondSquared: accelerometer.y,
          azMetersPerSecondSquared: accelerometer.z,
        ),
      );
    });
  }

  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _latestAccelerometer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
