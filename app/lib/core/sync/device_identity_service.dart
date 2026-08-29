import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const _key = 'opaque_device_id_v1';

  Future<String> id() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key);
    if (existing != null) return existing;
    final created = const Uuid().v4();
    await preferences.setString(_key, created);
    return created;
  }
}
