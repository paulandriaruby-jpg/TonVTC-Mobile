import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/driver_api.dart';
import '../models/models.dart';
import '../recruitment/recruitment.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Informations du dossier de recrutement : statut, adresse, SIRET, IBAN et, hors auto-entrepreneur, société.
// Lecture seule une fois le dossier relu par l'équipe. Renvoie le profil mis à jour.
class RecruitmentDetailsScreen extends StatefulWidget {
  const RecruitmentDetailsScreen({super.key, required this.profile});

  final DriverProfile profile;

  @override
  State<RecruitmentDetailsScreen> createState() => _RecruitmentDetailsScreenState();
}

class _RecruitmentDetailsScreenState extends State<RecruitmentDetailsScreen> {
  late String _legalStatus = widget.profile.details.legalStatus;
  late final _address = TextEditingController(text: widget.profile.details.address);
  late final _postcode = TextEditingController(text: widget.profile.details.postcode);
  late final _city = TextEditingController(text: widget.profile.details.city);
  late final _siret = TextEditingController(text: widget.profile.details.siret);
  late final _iban = TextEditingController(text: widget.profile.details.iban);
  late final _businessName = TextEditingController(text: widget.profile.details.businessName);
  late final _rcs = TextEditingController(text: widget.profile.details.rcsCode);
  late final _capital = TextEditingController(text: widget.profile.details.shareCapital);
  bool _saving = false;
  String? _error;

  bool get _locked => widget.profile.locked;
  bool get _corporate => _legalStatus != 'self_employed';

  @override
  void dispose() {
    for (final controller in [_address, _postcode, _city, _siret, _iban, _businessName, _rcs, _capital]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final problem = detailsError(
      legalStatus: _legalStatus,
      address: _address.text,
      postcode: _postcode.text,
      city: _city.text,
      iban: _iban.text,
      siret: _siret.text,
      businessName: _businessName.text,
      rcsCode: _rcs.text,
      shareCapital: _capital.text,
    );
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<DriverApi>().saveDetails({
        'legal_status': _legalStatus,
        'address': _address.text.trim(),
        'postcode': _postcode.text.trim(),
        'city': _city.text.trim(),
        'siret': _siret.text.replaceAll(' ', ''),
        'iban': _iban.text.trim(),
        'business_name': _corporate ? _businessName.text.trim() : '',
        'rcs_code': _corporate ? _rcs.text.trim() : '',
        'share_capital': _corporate ? double.tryParse(_capital.text.replaceAll(',', '.')) : null,
      });
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes informations')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_locked)
          const SectionCard(
            color: AppColors.brandSoft,
            child: Text('Votre dossier est en cours de validation : ces informations ne sont plus modifiables. Contactez-nous pour toute modification.'),
          ),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Statut', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _legalStatus,
              decoration: const InputDecoration(labelText: 'Statut juridique'),
              items: [for (final entry in legalStatuses.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
              onChanged: _locked ? null : (value) => setState(() => _legalStatus = value ?? _legalStatus),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _siret,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'SIRET', helperText: '14 chiffres'),
            ),
            if (_corporate) ...[
              const SizedBox(height: 10),
              TextField(controller: _businessName, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom de la société')),
              const SizedBox(height: 10),
              TextField(controller: _rcs, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ville du RCS')),
              const SizedBox(height: 10),
              TextField(controller: _capital, enabled: !_locked, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Capital social (€)')),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Adresse', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(controller: _address, enabled: !_locked, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Adresse')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _postcode, enabled: !_locked, decoration: const InputDecoration(labelText: 'Code postal'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextField(controller: _city, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ville'))),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Versement de vos gains', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _iban,
              enabled: !_locked,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'IBAN', helperText: 'Compte sur lequel vos relevés sont payés'),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          SectionCard(color: AppColors.dangerSoft, child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
        if (!_locked) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer'),
          ),
        ],
      ]),
    );
  }
}
