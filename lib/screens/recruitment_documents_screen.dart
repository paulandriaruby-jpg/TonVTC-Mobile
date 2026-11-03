import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/driver_api.dart';
import '../models/models.dart';
import '../recruitment/document_picker.dart';
import '../recruitment/recruitment.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/document_card.dart';

// Pièces justificatives du dossier : photo ou PDF de chaque document, avec numéros et dates de validité.
// Les fichiers s'envoient tout de suite ; les numéros et dates avec « Enregistrer ». Renvoie le profil à jour.
class RecruitmentDocumentsScreen extends StatefulWidget {
  const RecruitmentDocumentsScreen({super.key, required this.profile});

  final DriverProfile profile;

  @override
  State<RecruitmentDocumentsScreen> createState() => _RecruitmentDocumentsScreenState();
}

class _RecruitmentDocumentsScreenState extends State<RecruitmentDocumentsScreen> {
  late DriverProfile _profile = widget.profile;
  late String? _identityType = _profile.details.identityType;
  late String? _identityExpiry = _profile.details.identityExpiry;
  late String? _vtcExpiry = _profile.details.vtcExpiry;
  late final _vtcNumber = TextEditingController(text: _profile.details.vtcCardNumber);
  String? _busyKind;
  bool _saving = false;
  String? _error;

  bool get _locked => _profile.locked;

  @override
  void dispose() {
    _vtcNumber.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final profile = await context.read<DriverApi>().profile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _add(DocumentSpec spec) async {
    final source = await chooseDocumentSource(context);
    if (source == null || !mounted) return;
    final api = context.read<DriverApi>();
    final picker = context.read<DocumentPicker>();
    setState(() {
      _busyKind = spec.kind;
      _error = null;
    });
    try {
      final file = await picker.pick(source);
      if (file == null) return;
      await api.uploadDocument(kind: spec.kind, bytes: file.bytes, filename: file.filename);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<void> _remove(DriverDocument document) async {
    final ok = await confirmRemoveDocument(context, document);
    if (!ok || !mounted) return;
    setState(() {
      _busyKind = document.kind;
      _error = null;
    });
    try {
      await context.read<DriverApi>().deleteDocument(document.id);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<String?> _pickDate(String? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current ?? '') ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
      helpText: 'Date de fin de validité',
    );
    return picked == null ? current : DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<DriverApi>().saveDetails({
        'identity_type': _identityType,
        'identity_expiry': _identityExpiry,
        'vtc_card_number': _vtcNumber.text.trim(),
        'vtc_expiry': _vtcExpiry,
      });
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations enregistrées.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _date(String? iso) {
    final date = DateTime.tryParse(iso ?? '');
    return date == null ? 'Choisir une date' : DateFormat('d MMMM yyyy', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_profile);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mes documents')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_locked)
            const SectionCard(
              color: AppColors.brandSoft,
              child: Text('Votre dossier est en cours de validation : les documents ne sont plus modifiables. Contactez-nous pour toute modification.'),
            ),
          for (final spec in personalDocuments(_profile.details.legalStatus)) ...[
            _documentCard(spec),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            SectionCard(color: AppColors.dangerSoft, child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
          ],
          if (!_locked)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer les numéros et dates'),
            ),
        ]),
      ),
    );
  }

  Widget _documentCard(DocumentSpec spec) {
    return DocumentCard(
      spec: spec,
      files: _profile.documents.where((d) => d.kind == spec.kind).toList(),
      missing: _profile.documentsMissing.contains(spec.kind),
      locked: _locked,
      busy: _busyKind == spec.kind,
      disabled: _busyKind != null,
      onAdd: () => _add(spec),
      onRemove: _remove,
      children: [
        if (spec.kind == 'identity') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _identityType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type de pièce'),
            items: [for (final entry in identityTypes.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))],
            onChanged: _locked ? null : (value) => setState(() => _identityType = value),
          ),
          const SizedBox(height: 10),
          _dateField('Fin de validité', _identityExpiry, (value) => setState(() => _identityExpiry = value)),
        ],
        if (spec.kind == 'vtc_card') ...[
          const SizedBox(height: 12),
          TextField(controller: _vtcNumber, enabled: !_locked, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Numéro de carte VTC')),
          const SizedBox(height: 10),
          _dateField('Fin de validité', _vtcExpiry, (value) => setState(() => _vtcExpiry = value)),
        ],
      ],
    );
  }

  Widget _dateField(String label, String? value, void Function(String?) onChanged) {
    return InkWell(
      onTap: _locked ? null : () async => onChanged(await _pickDate(value)),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(_date(value)),
      ),
    );
  }
}
