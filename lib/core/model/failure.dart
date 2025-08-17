abstract class Failure {
  final String errorMessage;

  Failure({required this.errorMessage});
}

class AuthFailure extends Failure {
  AuthFailure({required super.errorMessage});
}
