class GuardSession {
  const GuardSession({
    required this.guardId,
    required this.name,
    required this.password,
    this.loginTime,
  });

  final String guardId;
  final String name;
  final String password;
  final String? loginTime;
}
