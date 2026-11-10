import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../models/models.dart';
import '../payments/stripe_sheet.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

// Paiement d'une course sans quitter l'app : un appui ouvre la fenêtre de paiement Stripe (carte, Google Pay),
// puis le paiement est confirmé auprès de l'API (qui le relit chez Stripe). onPaid : la course est réglée.
class PayButton extends StatefulWidget {
  const PayButton({super.key, required this.api, required this.reference, required this.amount, required this.onPaid, this.present = presentStripeSheet});

  final ClientApi api;
  final String reference;
  final double amount;
  final VoidCallback onPaid;
  // Fenêtre de paiement (remplaçable dans les tests).
  final Future<bool> Function(PaymentSheetData data) present;

  @override
  State<PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<PayButton> {
  bool _busy = false;
  bool _confirming = false;
  String? _message;

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await widget.api.paymentSheet(widget.reference);
      if (!await widget.present(data)) return; // fenêtre fermée : rien n'est débité
      if (mounted) setState(() => _confirming = true);
      await _confirm();
    } on PaymentFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  // La banque peut confirmer quelques secondes après la fin du paiement.
  Future<void> _confirm() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (await widget.api.confirmPayment(widget.reference) == 'paid') return widget.onPaid();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    if (mounted) setState(() => _message = 'Paiement effectué, confirmation en attente : vous recevrez un e-mail dès qu\'il sera validé.');
  }

  Future<void> _simulate() async {
    try {
      await widget.api.simulatePayment(widget.reference);
      widget.onPaid();
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Votre course sera proposée aux chauffeurs dès son paiement.', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(50)),
        onPressed: _busy ? null : _pay,
        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_outline),
        label: Text(_confirming ? 'Confirmation du paiement...' : 'Payer ${money(widget.amount)}'),
      ),
      if (_message != null) ...[
        const SizedBox(height: 6),
        Text(_message!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
      ],
      const SizedBox(height: 8),
      const Row(children: [
        Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
        SizedBox(width: 6),
        Expanded(child: Text('Carte ou Google Pay, paiement sécurisé par Stripe.', style: TextStyle(color: AppColors.muted, fontSize: 12))),
      ]),
      if (kDebugMode) TextButton(onPressed: _busy ? null : _simulate, child: const Text('Simuler le paiement (test)')),
    ]);
  }
}
