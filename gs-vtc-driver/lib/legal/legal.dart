import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

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
