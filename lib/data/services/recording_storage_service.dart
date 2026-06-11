import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../models/recording_session_paths.dart';

class RecordingStorageService {
  Future<RecordingSessionPaths> createSessionPaths() async {
    final root = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final folderStamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)}-${_two(now.hour)}-${_two(now.minute)}-${_two(now.second)}';
    final fileStamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)}-${_two(now.hour)}-${_two(now.minute)}';
    final sessionDir = Directory(
      '${root.path}${Platform.pathSeparator}recordings${Platform.pathSeparator}$folderStamp',
    );
    await sessionDir.create(recursive: true);

    final videoFileName = 'GC_$fileStamp.mov';
    final gcsvFileName = 'GC_$fileStamp.gcsv';

    return RecordingSessionPaths(
      baseName: 'GC_$fileStamp',
      videoPath: '${sessionDir.path}${Platform.pathSeparator}$videoFileName',
      gcsvPath: '${sessionDir.path}${Platform.pathSeparator}$gcsvFileName',
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
