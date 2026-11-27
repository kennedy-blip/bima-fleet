import 'package:flutter/foundation.dart';

enum ComplianceState { valid, expiringSoon, expired }

@immutable
class FleetVehicle {
  const FleetVehicle({
    required this.id,
    required this.plate,
    required this.model,
    required this.driver,
    required this.insuranceExpiry,
    required this.inspectionExpiry,
    required this.licenseExpiry,
    this.odometer = 0,
    this.oilInterval = 5000,
    this.tyreInterval = 40000,
    this.brakeInterval = 20000,
    this.lastOilAt = 0,
    this.lastTyreAt = 0,
    this.lastBrakeAt = 0,
  });

  final String id, plate, model, driver;
  final DateTime insuranceExpiry, inspectionExpiry, licenseExpiry;
  final int odometer, oilInterval, tyreInterval, brakeInterval;
  final int lastOilAt, lastTyreAt, lastBrakeAt;

  FleetVehicle copyWith({
    String? plate, String? model, String? driver,
    DateTime? insuranceExpiry, DateTime? inspectionExpiry, DateTime? licenseExpiry,
    int? odometer, int? oilInterval, int? tyreInterval, int? brakeInterval,
    int? lastOilAt, int? lastTyreAt, int? lastBrakeAt,
  }) => FleetVehicle(
    id: id, plate: plate ?? this.plate, model: model ?? this.model,
    driver: driver ?? this.driver,
    insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
    inspectionExpiry: inspectionExpiry ?? this.inspectionExpiry,
    licenseExpiry: licenseExpiry ?? this.licenseExpiry,
    odometer: odometer ?? this.odometer,
    oilInterval: oilInterval ?? this.oilInterval,
    tyreInterval: tyreInterval ?? this.tyreInterval,
    brakeInterval: brakeInterval ?? this.brakeInterval,
    lastOilAt: lastOilAt ?? this.lastOilAt,
    lastTyreAt: lastTyreAt ?? this.lastTyreAt,
    lastBrakeAt: lastBrakeAt ?? this.lastBrakeAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'plate': plate, 'model': model, 'driver': driver,
    'insuranceExpiry': insuranceExpiry.toIso8601String(),
    'inspectionExpiry': inspectionExpiry.toIso8601String(),
    'licenseExpiry': licenseExpiry.toIso8601String(),
    'odometer': odometer, 'oilInterval': oilInterval, 'tyreInterval': tyreInterval,
    'brakeInterval': brakeInterval, 'lastOilAt': lastOilAt,
    'lastTyreAt': lastTyreAt, 'lastBrakeAt': lastBrakeAt,
  };

  factory FleetVehicle.fromJson(Map<String, dynamic> j) => FleetVehicle(
    id: j['id'], plate: j['plate'], model: j['model'], driver: j['driver'],
    insuranceExpiry: DateTime.parse(j['insuranceExpiry']),
    inspectionExpiry: DateTime.parse(j['inspectionExpiry']),
    licenseExpiry: DateTime.parse(j['licenseExpiry']),
    odometer: j['odometer'] ?? 0, oilInterval: j['oilInterval'] ?? 5000,
    tyreInterval: j['tyreInterval'] ?? 40000, brakeInterval: j['brakeInterval'] ?? 20000,
    lastOilAt: j['lastOilAt'] ?? 0, lastTyreAt: j['lastTyreAt'] ?? 0,
    lastBrakeAt: j['lastBrakeAt'] ?? 0,
  );

  ComplianceState stateFor(DateTime expiry, {int threshold = 30}) {
    final days = DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime.now()).inDays;
    if (days < 0) return ComplianceState.expired;
    if (days <= threshold) return ComplianceState.expiringSoon;
    return ComplianceState.valid;
  }

  int daysUntil(DateTime expiry) => DateTime(expiry.year, expiry.month, expiry.day)
      .difference(DateTime.now()).inDays;
}

@immutable
class ServiceRecord {
  const ServiceRecord({
    required this.id, required this.vehicleId, required this.type,
    required this.date, required this.odometer, required this.cost,
    required this.garage, required this.notes,
  });
  final String id, vehicleId, type, garage, notes;
  final DateTime date;
  final int odometer;
  final double cost;

  Map<String, dynamic> toJson() => {
    'id': id, 'vehicleId': vehicleId, 'type': type,
    'date': date.toIso8601String(), 'odometer': odometer,
    'cost': cost, 'garage': garage, 'notes': notes,
  };
  factory ServiceRecord.fromJson(Map<String, dynamic> j) => ServiceRecord(
    id: j['id'], vehicleId: j['vehicleId'], type: j['type'],
    date: DateTime.parse(j['date']), odometer: j['odometer'],
    cost: (j['cost'] as num).toDouble(), garage: j['garage'], notes: j['notes'],
  );
}
