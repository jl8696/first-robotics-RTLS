class ReaderConfig {
  final String id;
  final String readerName;
  final double x;
  final double y;
  final String venueMapId;

  ReaderConfig({
    required this.id,
    required this.readerName,
    required this.x,
    required this.y,
    required this.venueMapId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'readerName': readerName,
      'x': x,
      'y': y,
      'venueMapId': venueMapId,
    };
  }

  factory ReaderConfig.fromJson(Map<String, dynamic> json) {
    return ReaderConfig(
      id: json['id'] as String,
      readerName: json['readerName'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      venueMapId: json['venueMapId'] as String,
    );
  }

  ReaderConfig copyWith({
    String? id,
    String? readerName,
    double? x,
    double? y,
    String? venueMapId,
  }) {
    return ReaderConfig(
      id: id ?? this.id,
      readerName: readerName ?? this.readerName,
      x: x ?? this.x,
      y: y ?? this.y,
      venueMapId: venueMapId ?? this.venueMapId,
    );
  }
}

