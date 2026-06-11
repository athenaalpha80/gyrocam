import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../models/recording_session_paths.dart';

class RecordingStorageService {
  Future<RecordingSessionPaths> createSessionPaths() async {
    final root = await getApplicationDocumentsDirectory();
    final recordingsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}recordings',
    );
    await recordingsDirectory.create(recursive: true);

    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final baseName = 'gyrocam_$stamp';
    final videoFileName = '$baseName.mov';

    return RecordingSessionPaths(
      baseName: baseName,
      videoPath:
          '${recordingsDirectory.path}${Platform.pathSeparator}$videoFileName',
      gcsvPath:
          '${recordingsDirectory.path}${Platform.pathSeparator}$baseName.gcsv',
      videoFileName: videoFileName,
    );
  }

  Future<void> persistRecording({
    required XFile sourceFile,
    required RecordingSessionPaths target,
  }) async {
    final source = File(sourceFile.path);
    final destination = File(target.videoPath);
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.copy(destination.path);
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class RecordingHeaderContext {
  const RecordingHeaderContext({
    required this.videoFileName,
    required this.orientation,
    required this.unixTimestampSeconds,
  });

  final String videoFileName;
  final String orientation;
  final int unixTimestampSeconds;
}
