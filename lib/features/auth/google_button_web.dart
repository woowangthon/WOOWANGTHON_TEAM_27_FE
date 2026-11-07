import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;

Widget googleSignInButton(BuildContext context, {required String languageCode, required double width}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return SizedBox(
    height: 44,
    width: width,
    child: gis.renderButton(
      configuration: gis.GSIButtonConfiguration(
        type: gis.GSIButtonType.standard,
        theme: dark ? gis.GSIButtonTheme.filledBlack : gis.GSIButtonTheme.outline,
        size: gis.GSIButtonSize.large,
        text: gis.GSIButtonText.continueWith,
        shape: gis.GSIButtonShape.pill,
        logoAlignment: gis.GSIButtonLogoAlignment.center,
        minimumWidth: width,
        locale: languageCode,
      ),
    ),
  );
}
