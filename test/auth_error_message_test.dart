import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:projek_tugas_akhir/utils/auth_error_message.dart';

void main() {
  test('shows a friendly message when authentication is canceled', () {
    const error = LocalAuthException(code: LocalAuthExceptionCode.userCanceled);

    expect(
      authErrorMessage(error),
      'Verifikasi dibatalkan. Coba lagi untuk membuka Flowly.',
    );
  });
}
