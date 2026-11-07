import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/toast.dart';

Widget googleSignInButton(BuildContext context, {required String languageCode, required double width}) {
  return SizedBox(
    width: width,
    child: OutlinedButton.icon(
      onPressed: () async {
        try {
          if (!GoogleSignIn.instance.supportsAuthenticate()) throw UnsupportedError('authenticate');
          await GoogleSignIn.instance.authenticate();
        } catch (e) {
          Toast.show(
            languageCode == 'ko'
                ? '이 기기에서는 아직 Google 로그인을 사용할 수 없어요.'
                : 'Google sign-in is not set up on this device yet.',
            type: ToastType.warning,
          );
        }
      },
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(languageCode == 'ko' ? 'Google로 계속하기' : 'Continue with Google'),
    ),
  );
}
