import 'package:goodwill/core/model/either.dart';
import 'package:goodwill/core/model/failure.dart';
import 'package:goodwill/features/auth/domain/entity/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithGoogle();
}
