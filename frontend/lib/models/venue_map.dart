class VenueMap {
  final String id;
  final String name;
  final String imagePath;

  VenueMap({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
    };
  }

  factory VenueMap.fromJson(Map<String, dynamic> json) {
    return VenueMap(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
    );
  }
}

