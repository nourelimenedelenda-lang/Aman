class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.date,
    required this.location,
    required this.method,
    required this.status,
    required this.color,
    this.latitude,
    this.longitude,
    this.description = '',
    this.vehicles = 1,
    this.photoPath,
  });

  final String id;
  final String type;
  final DateTime date;
  final String location;
  final String method;
  final String status;
  final String color;
  final double? latitude;
  final double? longitude;
  final String description;
  final int vehicles;
  final String? photoPath;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'date': date.toIso8601String(),
    'location': location,
    'method': method,
    'status': status,
    'color': color,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'vehicles': vehicles,
    'photoPath': photoPath,
  };

  factory Incident.fromJson(Map<String, Object?> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    return Incident(
      id: _requiredString(json, 'id'),
      type: _requiredString(json, 'type'),
      date: DateTime.parse(_requiredString(json, 'date')),
      location: _requiredString(json, 'location'),
      method: _requiredString(json, 'method'),
      status: _requiredString(json, 'status'),
      color: _requiredString(json, 'color'),
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      description: json['description'] as String? ?? '',
      vehicles: json['vehicles'] as int? ?? 1,
      photoPath: json['photoPath'] as String?,
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Incident is missing a valid "$key" value.');
    }
    return value;
  }
}
