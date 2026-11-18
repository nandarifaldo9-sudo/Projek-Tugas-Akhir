import 'package:local_auth/local_auth.dart';

String authErrorMessage(LocalAuthException error) {
  switch (error.code) {
    case LocalAuthExceptionCode.noCredentialsSet:
      return 'Atur PIN, pola, atau sandi layar di pengaturan perangkat, '
          'lalu coba lagi.';
    case LocalAuthExceptionCode.userCanceled:
      return 'Verifikasi dibatalkan. Coba lagi untuk membuka Flowly.';
    default:
      return error.description ?? error.code.name;
  }
}
