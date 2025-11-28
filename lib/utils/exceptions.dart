class IncompleteProfileException implements Exception {
  final String message;

  IncompleteProfileException([this.message = 'User profile is incomplete.']);

  @override
  String toString() => 'IncompleteProfileException: $message';
}
