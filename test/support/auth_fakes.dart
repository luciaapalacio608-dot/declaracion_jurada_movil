import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/repositories/pending_profile_repository.dart';
import 'package:declara_horario/repositories/teacher_directory_repository.dart';
import 'package:declara_horario/repositories/user_repository.dart';
import 'package:declara_horario/services/auth_service.dart';

/// Minimal fakes so DeclaraHorario's screens can be pumped without Firebase.
/// Any call a test does not expect fails loudly through [noSuchMethod].
class _FakeAuthService implements AuthService {
  @override
  bool get isEmailVerified => true;

  @override
  String? get currentEmail => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTeacherDirectory implements TeacherDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePendingProfiles implements PendingProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An [AuthState] with no session that never touches Firebase (it is not
/// initialized, so it listens to nothing).
AuthState signedOutAuthState() => AuthState(
      authService: _FakeAuthService(),
      userRepository: _FakeUserRepository(),
      teacherDirectory: _FakeTeacherDirectory(),
      pendingProfiles: _FakePendingProfiles(),
    );
