class MotionDataCapabilities {
  const MotionDataCapabilities({
    required this.isSupported,
    required this.sampleRateOptionsHz,
    required this.minSampleRateHz,
    required this.maxSampleRateHz,
  });

  factory MotionDataCapabilities.fromMap(Map<Object?, Object?> map) {
    final sampleRates = (map['sampleRateOptionsHz'] as List<Object?>? ??
            const <Object?>[])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList()
      ..sort();

    return MotionDataCapabilities(
      isSupported: map['isSupported'] as bool? ?? sampleRates.isNotEmpty,
      sampleRateOptionsHz: sampleRates,
      minSampleRateHz: (map['minSampleRateHz'] as num?)?.toInt() ??
          (sampleRates.isEmpty ? 0 : sampleRates.first),
      maxSampleRateHz: (map['maxSampleRateHz'] as num?)?.toInt() ??
          (sampleRates.isEmpty ? 0 : sampleRates.last),
    );
  }

  final bool isSupported;
  final List<int> sampleRateOptionsHz;
  final int minSampleRateHz;
  final int maxSampleRateHz;
}
