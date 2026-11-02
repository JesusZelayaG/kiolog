import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/config_tables.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<UserProfile?> getProfile() => select(userProfiles).getSingleOrNull();

  Future<bool> isOnboardingComplete() async {
    final profile = await getProfile();
    return profile?.onboardingCompleted ?? false;
  }

  Future<int> createProfile() => into(userProfiles).insert(
        const UserProfilesCompanion(),
      );

  Future<void> completeOnboarding(DateTime registrationDate) async {
    final profile = await getProfile();
    if (profile == null) {
      await into(userProfiles).insert(
        UserProfilesCompanion(
          onboardingCompleted: const Value(true),
          registrationDate: Value(registrationDate),
        ),
      );
    } else {
      await update(userProfiles).write(
        UserProfilesCompanion(
          onboardingCompleted: const Value(true),
          registrationDate: Value(registrationDate),
        ),
      );
    }
  }

  Future<void> updateProfileName(String name) async {
    final profile = await getProfile();
    if (profile == null) return;
    await update(userProfiles).write(
      UserProfilesCompanion(name: Value(name)),
    );
  }

  Future<void> updateBodySex(String sex) async {
    final profile = await getProfile();
    if (profile == null) {
      await into(userProfiles).insert(UserProfilesCompanion(bodySex: Value(sex)));
    } else {
      await update(userProfiles).write(UserProfilesCompanion(bodySex: Value(sex)));
    }
  }
}
