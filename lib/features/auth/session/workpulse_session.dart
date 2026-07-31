import 'package:flutter/material.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';

class WorkPulseSessionController extends ChangeNotifier {
  WorkPulseSessionController({
    required WorkPulseUserProfile profile,
    required AuthService authService,
  }) : _profile = profile,
       _authService = authService;

  final AuthService _authService;
  WorkPulseUserProfile _profile;

  WorkPulseUserProfile get profile => _profile;

  Future<void> refreshProfile() async {
    try {
      final WorkPulseUserProfile? refreshedProfile = await _authService
          .fetchCurrentProfile();
      if (refreshedProfile == null) {
        return;
      }
      _profile = refreshedProfile;
      notifyListeners();
    } catch (_) {
      // Keep the last verified session profile during transient network errors.
    }
  }
}

class WorkPulseSessionScope
    extends InheritedNotifier<WorkPulseSessionController> {
  const WorkPulseSessionScope({
    required WorkPulseSessionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WorkPulseSessionController? maybeControllerOf(
    BuildContext context, {
    bool listen = true,
  }) {
    final WorkPulseSessionScope? scope = listen
        ? context.dependOnInheritedWidgetOfExactType<WorkPulseSessionScope>()
        : context.getInheritedWidgetOfExactType<WorkPulseSessionScope>();
    return scope?.notifier;
  }

  static WorkPulseUserProfile? maybeProfileOf(
    BuildContext context, {
    bool listen = true,
  }) {
    return maybeControllerOf(context, listen: listen)?.profile;
  }
}
