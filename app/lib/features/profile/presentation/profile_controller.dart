import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

final userProfileProvider =
    AsyncNotifierProvider<UserProfileController, UserProfile>(
      UserProfileController.new,
    );

class UserProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const UserProfile(userId: 'unknown', fullName: '');
    }
    if (user.isGuest) {
      return UserProfile(userId: user.id, fullName: '', isGuest: true);
    }
    final stored = await ref.read(profileRepositoryProvider).load(user.id);
    if (stored != null) {
      final refreshed = stored.copyWith(
        email: stored.email.isEmpty ? user.email ?? '' : stored.email,
        photoUrl: stored.photoUrl ?? user.photoUrl,
      );
      if (refreshed.toJson().toString() != stored.toJson().toString()) {
        await ref.read(profileRepositoryProvider).save(refreshed);
      }
      return refreshed;
    }
    final profile = UserProfile(
      userId: user.id,
      fullName: user.isGuest ? '' : user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoUrl,
      isGuest: user.isGuest,
    );
    await ref.read(profileRepositoryProvider).save(profile);
    return profile;
  }

  Future<void> save(UserProfile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).save(profile);
      return profile;
    });
  }
}
