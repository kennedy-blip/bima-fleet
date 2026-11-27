import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/fleet_models.dart';

class FleetStore {
  static const _boxName = 'bimafleet_v1';
  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    if (!_box.containsKey('vehicles')) await _box.put('vehicles', '[]');
    if (!_box.containsKey('services')) await _box.put('services', '[]');
    if (!_box.containsKey('threshold')) await _box.put('threshold', '30');
  }

  List<FleetVehicle> get vehicles => (jsonDecode(_box.get('vehicles', defaultValue: '[]')!) as List)
      .map((e) => FleetVehicle.fromJson(Map<String, dynamic>.from(e))).toList();
  List<ServiceRecord> get services => (jsonDecode(_box.get('services', defaultValue: '[]')!) as List)
      .map((e) => ServiceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
  int get threshold => int.tryParse(_box.get('threshold', defaultValue: '30')!) ?? 30;
  Future<void> saveVehicles(List<FleetVehicle> value) =>
      _box.put('vehicles', jsonEncode(value.map((e) => e.toJson()).toList()));
  Future<void> saveServices(List<ServiceRecord> value) =>
      _box.put('services', jsonEncode(value.map((e) => e.toJson()).toList()));
  Future<void> setThreshold(int value) => _box.put('threshold', '$value');
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'BimaFleet backup v1', 'exportedAt': DateTime.now().toIso8601String(),
    'vehicles': vehicles.map((e) => e.toJson()).toList(),
    'services': services.map((e) => e.toJson()).toList(),
    'alertThresholdDays': threshold,
  });
  String get storageStatus => 'Hive local database · ${_box.length} keys';
  Future<void> close() => _box.close();
}
