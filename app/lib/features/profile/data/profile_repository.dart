import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  const ProfileRepository(this._database);
  final AppDatabase _database;
  static const _keyPrefix = 'user_profile_v1_';

  Future<UserProfile?> load(String userId) async {
    final rows = await _database.database.query(
      'secure_profiles',
      columns: ['profile_json'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return UserProfile.fromJson(
        jsonDecode(rows.single['profile_json']! as String)
            as Map<String, Object?>,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final legacyKey = '$_keyPrefix$userId';
    final value = preferences.getString(legacyKey);
    if (value == null) return null;
    final profile = UserProfile.fromJson(
      jsonDecode(value) as Map<String, Object?>,
    );
    await save(profile);
    await preferences.remove(legacyKey);
    return profile;
  }

  Future<void> save(UserProfile profile) async {
    await _database.database.insert('secure_profiles', {
      'user_id': profile.userId,
      'profile_json': jsonEncode(profile.toJson()),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await (await SharedPreferences.getInstance()).remove(
      '$_keyPrefix${profile.userId}',
    );
  }
}
