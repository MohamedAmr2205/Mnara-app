/// Route paths from the screen table (session screens hide the nav bar).
abstract final class AppRoutes {
  static const String boot = '/boot';
  static const String signIn = '/signin';
  static const String warming = '/warming';
  static const String pinSetup = '/pin-setup';
  static const String lock = '/lock';
  static const String unlock = '/unlock';
  static const String groups = '/groups';
  static const String search = '/search';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String changePin = '/settings/pin';
  static const String sync = '/sync';
  static const String group = '/groups/:gid';
  static const String startSession = '/groups/:gid/start';
  static const String session = '/session/:xid';
  static const String finishSession = '/session/:xid/finish';
  static const String student = '/students/:sid';
  static const String payment = '/students/:sid/pay';

  /// Path of a group's details screen.
  static String groupPath(String gid) => '/groups/$gid';

  /// Path of the start-session screen.
  static String startPath(String gid) => '/groups/$gid/start';

  /// Path of a session; `edit` opens it in edit mode.
  static String sessionPath(String xid, {bool edit = false}) =>
      edit ? '/session/$xid?edit=1' : '/session/$xid';

  /// Path of the finish screen.
  static String finishPath(String xid, {bool edit = false}) =>
      edit ? '/session/$xid/finish?edit=1' : '/session/$xid/finish';

  /// Path of a student profile.
  static String studentPath(String sid) => '/students/$sid';

  /// Path of the payment screen.
  static String paymentPath(String sid) => '/students/$sid/pay';
}
