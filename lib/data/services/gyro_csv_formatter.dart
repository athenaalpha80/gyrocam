import 'recording_storage_service.dart';

class GyroCsvFormatter {
  const GyroCsvFormatter._();

  static const double gravityInMetersPerSecondSquared = 9.80665;
  static const String headerTimeScale = '0.000001';
  static const String unitScale = '1';

  static String buildHeader({
    required RecordingHeaderContext context,
  }) {
    final buffer = StringBuffer()
      ..writeln('GYROFLOW IMU LOG')
      ..writeln('version,1.3')
      ..writeln('id,gyrocam_ios_manual')
      ..writeln('orientation,${context.orientation}')
      ..writeln('note,gyrocam_video_recording')
      ..writeln('fwversion,ios_flutter_v1')
      ..writeln('timestamp,${context.unixTimestampSeconds}')
      ..writeln('vendor,gyrocam')
      ..writeln('videofilename,${context.videoFileName}')
      ..writeln('lens_info,rear_wide')
      ..writeln('frame_readout_direction,0')
      ..writeln('tscale,$headerTimeScale')
      ..writeln('gscale,$unitScale')
      ..writeln('ascale,$unitScale')
      ..writeln('t,gx,gy,gz,ax,ay,az');
    return buffer.toString();
  }

  static String buildDataRow({
    required int elapsedMicros,
    required double gx,
    required double gy,
    required double gz,
    required double axMetersPerSecondSquared,
    required double ayMetersPerSecondSquared,
    required double azMetersPerSecondSquared,
  }) {
    return [
      '$elapsedMicros',
      _format(gx),
      _format(gy),
      _format(gz),
      _format(axMetersPerSecondSquared / gravityInMetersPerSecondSquared),
      _format(ayMetersPerSecondSquared / gravityInMetersPerSecondSquared),
      _format(azMetersPerSecondSquared / gravityInMetersPerSecondSquared),
    ].join(',');
  }

  static String _format(double value) => value.toStringAsFixed(6);
}
