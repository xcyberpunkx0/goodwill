import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwill/core/model/either.dart';
import 'package:goodwill/core/model/failure.dart';
import 'package:goodwill/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:goodwill/features/auth/domain/entity/user_entity.dart';
import 'package:goodwill/features/auth/domain/repository/auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Implementation of the AuthRepository interface that handles authentication operations.
///
/// This class serves as the concrete implementation of the authentication repository,
/// coordinating between Google Sign-In, Firebase Authentication, and the remote data source.
/// It follows the Repository pattern from Clean Architecture, acting as a bridge between
/// the domain layer and the data layer.
///
/// Key responsibilities:
/// - Orchestrate Google Sign-In flow
/// - Handle Firebase Authentication integration
/// - Manage authentication tokens
/// - Convert platform-specific exceptions to domain failures
/// - Coordinate with remote data source for backend authentication
class AuthRepositoryImpl implements AuthRepository {
  /// Remote data source for handling backend authentication API calls
  final AuthRemoteDatasource authRemoteDatasource;

  /// Google Sign-In instance for handling Google authentication flow
  final GoogleSignIn googleSignIn;

  /// Constructor that injects required dependencies
  ///
  /// [authRemoteDatasource] - Handles communication with the backend authentication API
  /// [googleSignIn] - Manages Google Sign-In authentication flow
  AuthRepositoryImpl({
    required this.authRemoteDatasource,
    required this.googleSignIn,
  });

  /// Handles Google Sign-In authentication flow
  ///
  /// This method orchestrates the complete Google Sign-In process:
  /// 1. Initializes Google Sign-In
  /// 2. Authenticates user with Google
  /// 3. Obtains necessary authorization tokens
  /// 4. Creates Firebase credentials
  /// 5. Signs in with Firebase
  /// 6. Retrieves Firebase ID token
  /// 7. Sends token to backend for user creation/validation
  ///
  /// Returns:
  /// - [Right<UserEntity>] on successful authentication with user data
  /// - [Left<Failure>] on any error during the authentication process
  ///
  /// Possible failures:
  /// - Google Sign-In cancellation or failure
  /// - Firebase authentication failure
  /// - Backend API errors
  /// - Network connectivity issues
  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      // Step 1: Initialize Google Sign-In service
      await googleSignIn.initialize();

      // Step 2: Authenticate user with Google (shows Google sign-in UI)
      final googleUser = await googleSignIn.authenticate();

      // Step 3: Get Google authentication credentials (note: removed incorrect await)
      final googleAuth = googleUser.authentication;

      // Step 4: Request authorization for specific Google API scopes
      // These scopes allow access to user's email and profile information
      final authorizationToken = await googleUser.authorizationClient
          .authorizationForScopes([
            'https://www.googleapis.com/auth/userinfo.email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ]);

      // Step 5: Create Firebase credential using Google tokens
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: authorizationToken?.accessToken,
      );

      // Step 6: Sign in to Firebase using Google credentials
      final firebaseCredentials = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // Step 7: Get Firebase ID token for backend authentication
      final token = await firebaseCredentials.user?.getIdToken();

      // Step 8: Send Firebase token to backend and get user data
      if (token != null) {
        return Right(await authRemoteDatasource.signInWithGoogle(token));
      } else {
        // Handle case where Firebase token is null
        return Left(
          AuthFailure(errorMessage: 'Failed to obtain authentication token'),
        );
      }
    } on DioException catch (e) {
      // Handle network/API errors from backend calls
      return Left(
        AuthFailure(
          errorMessage: e.response?.data['message'] ?? 'Network error occurred',
        ),
      );
    } catch (e) {
      // Handle any other unexpected errors (Google Sign-In, Firebase, etc.)
      return Left(
        AuthFailure(errorMessage: 'Authentication failed: ${e.toString()}'),
      );
    }
  }
}
