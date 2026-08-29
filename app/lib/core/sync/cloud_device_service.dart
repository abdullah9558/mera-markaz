import 'package:cloud_firestore/cloud_firestore.dart';

import '../security/crypto/crypto_envelope.dart';
import '../security/crypto/key_enrollment_service.dart';
import 'device_identity_service.dart';

class AuthorizedDevice {
  const AuthorizedDevice({
    required this.id,
    required this.label,
    required this.status,
    this.lastSeenAt,
  });
  final String id;
  final String label;
  final String status;
  final DateTime? lastSeenAt;
}

class CloudDeviceService {
  CloudDeviceService({
    FirebaseFirestore? firestore,
    DeviceIdentityService? identities,
    KeyEnrollmentService? enrollment,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identities = identities ?? DeviceIdentityService(),
       _enrollment = enrollment ?? KeyEnrollmentService();

  final FirebaseFirestore _firestore;
  final DeviceIdentityService _identities;
  final KeyEnrollmentService _enrollment;

  Future<String> registerCurrentDevice(
    String uid, {
    String label = 'Android device',
  }) async {
    final deviceId = await _identities.id();
    await _firestore.doc('users/$uid/devices/$deviceId').set({
      'deviceId': deviceId,
      'label': label,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'keyVersion': 1,
      'wrappedKey': null,
    }, SetOptions(merge: true));
    return deviceId;
  }

  Future<void> uploadRecoveryEnvelope(String uid) async {
    final wrapped = await _enrollment.recoveryWrappedKey(uid);
    final envelope = wrapped.envelope;
    await _firestore.doc('users/$uid/recovery/current').set({
      'version': 1,
      'kdf': wrapped.kdf,
      'salt': wrapped.toJson()['salt'],
      'nonce': envelope.toJson()['nonce'],
      'ciphertext': envelope.toJson()['ciphertext'],
      'tag': envelope.toJson()['tag'],
      'keyVersion': envelope.keyVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<RecoveryWrappedKey> downloadRecoveryEnvelope(String uid) async {
    final snapshot = await _firestore.doc('users/$uid/recovery/current').get();
    final data = snapshot.data();
    if (data == null || data['version'] != 1) {
      throw StateError('No encrypted recovery material was found.');
    }
    return RecoveryWrappedKey.fromJson({
      'kdf': data['kdf'],
      'salt': data['salt'],
      'envelope': {
        'algorithm': 'AES-256-GCM',
        'schemaVersion': 1,
        'keyVersion': data['keyVersion'],
        'nonce': data['nonce'],
        'ciphertext': data['ciphertext'],
        'tag': data['tag'],
      },
    });
  }

  Stream<List<AuthorizedDevice>> devices(String uid) => _firestore
      .collection('users/$uid/devices')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((document) {
          final data = document.data();
          return AuthorizedDevice(
            id: document.id,
            label: data['label'] as String? ?? 'Device',
            status: data['status'] as String? ?? 'pending',
            lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
          );
        }).toList(),
      );

  Future<void> revoke(String uid, String deviceId) =>
      _firestore.doc('users/$uid/devices/$deviceId').update({
        'status': 'revoked',
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
}
