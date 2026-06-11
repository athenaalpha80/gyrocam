import 'package:flutter_test/flutter_test.dart';
import 'package:gyrocam/data/services/gyro_csv_formatter.dart';
import 'package:gyrocam/data/services/recording_storage_service.dart';

void main() {
  test('gcsv header contains gyroflow metadata and filename', () {
    final header = GyroCsvFormatter.buildHeader(
      context: const RecordingHeaderContext(
        videoFileName: 'gyrocam_20260611_180000.mov',
        orientation: 'XYZ',
        unixTimestampSeconds: 1718123456,
      ),
    );

    expect(header, contains('GYROFLOW IMU LOG'));
    expect(header, contains('videofilename,gyrocam_20260611_180000.mov'));
    expect(header, contains('orientation,XYZ'));
    expect(header, contains('t,gx,gy,gz,ax,ay,az'));
  });

  test('gcsv row converts accelerometer values to g', () {
    final row = GyroCsvFormatter.buildDataRow(
      elapsedMicros: 1500,
      gx: 0.5,
      gy: -0.25,
      gz: 1.25,
      axMetersPerSecondSquared: 9.80665,
      ayMetersPerSecondSquared: 0,
      azMetersPerSecondSquared: -9.80665,
    );

    expect(row, '1500,0.500000,-0.250000,1.250000,1.000000,0.000000,-1.000000');
  });
}
