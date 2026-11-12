import 'package:flutter/material.dart';

import '../legal/legal.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Informations légales : mentions légales, CGV et politique de confidentialité (pages du site).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informations légales')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < legalPages.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(legalPages[i].icon, color: AppColors.brand),
                title: Text(legalPages[i].title),
                subtitle: const Text('Sur le site'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLegalPage(legalPages[i].path),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Ces textes s\'ouvrent dans votre navigateur. La politique de confidentialité décrit les données de votre dossier (pièces d\'identité, IBAN, documents du véhicule) et les notifications de cette application.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      ]),
    );
  }
}
