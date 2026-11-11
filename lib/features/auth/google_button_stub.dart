import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/toast.dart';
import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../data/calendar_controller.dart';

Widget googleSignInButton(BuildContext context, {required String languageCode, required double width}) {
  return SizedBox(
    width: width,
    child: OutlinedButton.icon(
      onPressed: () async {
        try {
          await initGoogleSignIn();
          if (!GoogleSignIn.instance.supportsAuthenticate()) throw UnsupportedError('authenticate');
          await GoogleSignIn.instance.authenticate();
        } catch (e) {
          if (!context.mounted) return;
          Toast.show(
            friendlyError(context.l10n, e),
            type: ToastType.warning,
          );
        }
      },
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(languageCode == 'ko' ? 'Google로 계속하기' : 'Continue with Google'),
    ),
  );
}
