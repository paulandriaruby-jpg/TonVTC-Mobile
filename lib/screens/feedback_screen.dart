import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Message à l'équipe TonVTC (suggestion, problème, compliment...), lu par les administrateurs.
// Ouvert depuis le compte, ou depuis une course (le message y est alors rattaché).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.bookingId, this.bookingLabel, this.initialCategory = 'suggestion'});

  final int? bookingId;
  final String? bookingLabel;
  final String initialCategory;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late String _category = widget.initialCategory;
  final _body = TextEditingController();
  bool _sending = false;

  static const _icons = {
    'suggestion': Icons.lightbulb_outline,
    'problem': Icons.report_problem_outlined,
    'compliment': Icons.favorite_border,
    'other': Icons.chat_bubble_outline,
  };

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await context.read<ClientApi>().sendFeedback(category: _category, body: _body.text.trim(), bookingId: widget.bookingId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci ! Votre message a bien été transmis à l\'équipe.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _body.text.trim().isNotEmpty && !_sending;
    return Scaffold(
      appBar: AppBar(title: const Text('Nous écrire')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Une idée, un souci, un compliment ? Votre message est lu par l\'équipe TonVTC.', style: TextStyle(color: AppColors.muted, height: 1.4)),
        if (widget.bookingLabel != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            color: AppColors.brandSoft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.directions_car_outlined, color: AppColors.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('À propos de la course du ${widget.bookingLabel}', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        const Text('Sujet', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in feedbackCategories.entries)
            ChoiceChip(
              avatar: Icon(_icons[entry.key], size: 18, color: _category == entry.key ? AppColors.brand : AppColors.muted),
              label: Text(entry.value),
              selected: _category == entry.key,
              showCheckmark: false,
              selectedColor: AppColors.brandSoft,
              side: BorderSide(color: _category == entry.key ? AppColors.brand : AppColors.line),
              labelStyle: TextStyle(color: _category == entry.key ? AppColors.brand : AppColors.ink, fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _category = entry.key),
            ),
        ]),
        const SizedBox(height: 18),
        TextField(
          controller: _body,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Votre message', alignLabelWithHint: true, hintText: 'Dites-nous en plus...'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: ready ? _send : null,
          icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_outlined),
          label: const Text('Envoyer'),
        ),
      ]),
    );
  }
}
