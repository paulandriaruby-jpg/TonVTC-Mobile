import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../models/models.dart';
import '../theme.dart';

// Ouvre la fenêtre de paiement native de Stripe (carte, Google Pay) par-dessus l'écran courant.
// Vrai si le paiement a abouti, faux si le client a fermé la fenêtre. Une erreur de paiement est levée en
// PaymentFailure avec le message de Stripe (en français).
class PaymentFailure implements Exception {
  const PaymentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<bool> presentStripeSheet(PaymentSheetData data) async {
  Stripe.publishableKey = data.publishableKey;
  await Stripe.instance.applySettings();
  try {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: data.clientSecret,
        merchantDisplayName: data.merchantName,
        googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'FR', currencyCode: 'EUR', testEnv: !kReleaseMode),
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: AppColors.brand),
          shapes: PaymentSheetShape(borderRadius: 10),
          primaryButton: PaymentSheetPrimaryButtonAppearance(
            colors: PaymentSheetPrimaryButtonTheme(light: PaymentSheetPrimaryButtonThemeColors(background: AppColors.accent, text: Colors.white)),
          ),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return true;
  } on StripeException catch (error) {
    if (error.error.code == FailureCode.Canceled) return false;
    throw PaymentFailure(error.error.localizedMessage ?? error.error.message ?? 'Le paiement a échoué.');
  }
}
