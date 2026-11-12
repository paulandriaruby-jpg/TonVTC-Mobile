import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

// Pages légales : elles se trouvent sur le site (un seul texte à tenir à jour) et s'ouvrent dans le navigateur.
class LegalPage {
  const LegalPage(this.title, this.path, this.icon);

  final String title;
  final String path;
  final IconData icon;
}

const legalPages = [
  LegalPage('Mentions légales', '/mentions-legales', Icons.gavel_outlined),
  LegalPage('Conditions générales de vente', '/cgv', Icons.description_outlined),
  LegalPage('Politique de confidentialité', '/confidentialite', Icons.privacy_tip_outlined),
];

Future<void> openLegalPage(String path) => launchUrl(Uri.parse('$siteUrl$path'), mode: LaunchMode.externalApplication);

// Phrase d'acceptation avec les deux liens : "<début> conditions générales de vente et la politique de confidentialité."
class TermsLine extends StatefulWidget {
  const TermsLine({super.key, required this.lead, this.textAlign = TextAlign.start, this.fontSize = 13});

  // Début de la phrase, par exemple "J'ai lu et j'accepte les ".
  final String lead;
  final TextAlign textAlign;
  final double fontSize;

  @override
  State<TermsLine> createState() => _TermsLineState();
}

class _TermsLineState extends State<TermsLine> {
  late final _cgv = TapGestureRecognizer()..onTap = () => openLegalPage('/cgv');
  late final _privacy = TapGestureRecognizer()..onTap = () => openLegalPage('/confidentialite');

  @override
  void dispose() {
    _cgv.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: AppColors.muted, fontSize: widget.fontSize, height: 1.35);
    final link = base.copyWith(color: AppColors.brand, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(style: base, text: widget.lead, children: [
        TextSpan(text: 'conditions générales de vente', style: link, recognizer: _cgv),
        const TextSpan(text: ' et la '),
        TextSpan(text: 'politique de confidentialité', style: link, recognizer: _privacy),
        const TextSpan(text: '.'),
      ]),
      textAlign: widget.textAlign,
    );
  }
}

// Case à cocher d'acceptation (obligatoire avant de créer un compte ou de confirmer une course).
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
      const Expanded(child: Padding(padding: EdgeInsets.only(top: 10), child: TermsLine(lead: "J'ai lu et j'accepte les "))),
    ]);
  }
}
