class CameraCapabilities {
  const CameraCapabilities({
    required this.formats,
    required this.minIso,
    required this.maxIso,
    required this.minShutterMicros,
    required this.maxShutterMicros,
    required this.minZoom,
    required this.maxZoom,
  });

  factory CameraCapabilities.fromMap(Map<Object?, Object?> map) {
    final formats = (map['formats'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(CameraFormatOption.fromMap)
        .toList()
      ..sort(CameraFormatOption.compareByQuality);

    return CameraCapabilities(
      formats: formats,
      minIso: (map['minIso'] as num?)?.toDouble() ?? 25,
      maxIso: (map['maxIso'] as num?)?.toDouble() ?? 2000,
      minShutterMicros: (map['minShutterMicros'] as num?)?.toInt() ?? 1000,
      maxShutterMicros:
          (map['maxShutterMicros'] as num?)?.toInt() ?? 1 * 1000 * 1000,
      minZoom: (map['minZoom'] as num?)?.toDouble() ?? 1,
      maxZoom: (map['maxZoom'] as num?)?.toDouble() ?? 6,
    );
  }

  final List<CameraFormatOption> formats;
  final double minIso;
  final double maxIso;
  final int minShutterMicros;
  final int maxShutterMicros;
  final double minZoom;
  final double maxZoom;
}

class CameraFormatOption {
  const CameraFormatOption({
    required this.width,
    required this.height,
    required this.fpsOptions,
  });

  factory CameraFormatOption.fromMap(Map<Object?, Object?> map) {
    final fps = (map['fpsOptions'] as List<Object?>? ?? const <Object?>[])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList()
      ..sort();

    return CameraFormatOption(
      width: (map['width'] as num?)?.toInt() ?? 1920,
      height: (map['height'] as num?)?.toInt() ?? 1080,
      fpsOptions: fps,
    );
  }

  static int compareByQuality(CameraFormatOption left, CameraFormatOption right) {
    final areaCompare = (right.width * right.height).compareTo(
      left.width * left.height,
    );
    if (areaCompare != 0) {
      return areaCompare;
    }
    final leftMaxFps = left.fpsOptions.isEmpty ? 0 : left.fpsOptions.last;
    final rightMaxFps = right.fpsOptions.isEmpty ? 0 : right.fpsOptions.last;
    return rightMaxFps.compareTo(leftMaxFps);
  }

  final int width;
  final int height;
  final List<int> fpsOptions;

  String get label => '${width}x$height';

  bool supportsFps(int fps) => fpsOptions.contains(fps);
}
