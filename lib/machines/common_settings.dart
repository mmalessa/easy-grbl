/// Settings shared by every working mode.
class CommonSettings {
  final int defaultBaudRate;

  const CommonSettings({this.defaultBaudRate = 115200});

  CommonSettings copyWith({int? defaultBaudRate}) =>
      CommonSettings(defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate);

  Map<String, Object> toMap() => {'defaultBaudRate': defaultBaudRate};

  factory CommonSettings.fromMap(Map<String, Object?> map) => CommonSettings(
        defaultBaudRate: map['defaultBaudRate'] as int? ?? 115200,
      );
}
