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

// Fiche d'un véhicule : caractéristiques puis ses pièces. Un véhicule validé n'est plus modifiable,
// sauf l'activation, la couleur et le wifi. Renvoie le profil à jour.
class RecruitmentCarScreen extends StatefulWidget {
  const RecruitmentCarScreen({super.key, required this.profile, this.carId});

  final DriverProfile profile;
  // Absent : nouveau véhicule.
  final int? carId;

  @override
  State<RecruitmentCarScreen> createState() => _RecruitmentCarScreenState();
}

class _RecruitmentCarScreenState extends State<RecruitmentCarScreen> {
  late DriverProfile _profile = widget.profile;
  late int? _carId = widget.carId;
  late final DriverCar? _initial = _profile.cars.where((c) => c.id == widget.carId).firstOrNull;
  late final _brand = TextEditingController(text: _initial?.brand);
  late final _model = TextEditingController(text: _initial?.model);
  late final _plate = TextEditingController(text: _initial?.plateNumber);
  late final _color = TextEditingController(text: _initial?.color);
  late final _seats = TextEditingController(text: _initial?.seats?.toString());
  late int? _vehicleTypeId = _initial?.vehicleTypeId;
  late String _motor = _initial?.motor ?? 'gas';
  late String? _firstRegistration = _initial?.firstRegistrationOn;
  late bool _wifi = _initial?.wifi ?? false;
  late bool _rental = _initial?.rental ?? false;
  late bool _enabled = _initial?.enabled ?? true;
  List<VehicleCategory> _categories = const [];
  String? _busyKind;
  bool _saving = false;
  String? _error;

  DriverCar? get _car => _profile.cars.where((c) => c.id == _carId).firstOrNull;
  // Véhicule validé ou dossier relu : caractéristiques réglementées figées.
  bool get _locked => _car?.locked ?? false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final controller in [_brand, _model, _plate, _color, _seats]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<DriverApi>().vehicleCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_vehicleTypeId == null && categories.length == 1) _vehicleTypeId = categories.first.id;
      });
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _refresh() async {
    final profile = await context.read<DriverApi>().profile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _save() async {
    final problem = carError(brand: _brand.text, model: _model.text, plate: _plate.text, vehicleTypeId: _vehicleTypeId, seats: _seats.text);
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<DriverApi>();
      final body = <String, dynamic>{
        'color': _color.text.trim(),
        'wifi': _wifi,
        'enabled': _enabled,
        if (!_locked) ...{
          'brand': _brand.text.trim(),
          'model': _model.text.trim(),
          'plate_number': _plate.text.trim(),
          'vehicle_type_id': _vehicleTypeId,
          'motor': _motor,
          'seats': _seats.text.trim().isEmpty ? null : int.parse(_seats.text.trim()),
          'first_registration_on': _firstRegistration,
          'rental': _rental,
        },
      };
      final saved = await api.saveCar(body, id: _carId);
      _carId = saved.id;
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Véhicule enregistré.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce véhicule ?'),
        content: const Text('Ses documents seront aussi supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<DriverApi>();
    try {
      await api.deleteCar(_carId!);
      final profile = await api.profile();
      if (mounted) Navigator.of(context).pop(profile);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
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
      await api.uploadDocument(kind: spec.kind, bytes: file.bytes, filename: file.filename, carId: _carId);
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
    if (!await confirmRemoveDocument(context, document) || !mounted) return;
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_firstRegistration ?? '') ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'Première mise en circulation',
    );
    if (picked != null) setState(() => _firstRegistration = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final car = _car;
    final field = !_locked;
    final date = DateTime.tryParse(_firstRegistration ?? '');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_profile);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(car?.name.isNotEmpty == true ? car!.name : 'Nouveau véhicule')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_locked)
            const SectionCard(
              color: AppColors.brandSoft,
              child: Text('Ce véhicule est validé : seuls son activation, sa couleur et le wifi restent modifiables. Contactez-nous pour toute autre modification.'),
            ),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Caractéristiques', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _brand, enabled: field, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Marque'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _model, enabled: field, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Modèle'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _plate, enabled: field, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Immatriculation', helperText: 'Exemple : AB-123-CD')),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _categories.any((c) => c.id == _vehicleTypeId) ? _vehicleTypeId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [for (final category in _categories) DropdownMenuItem(value: category.id, child: Text('${category.name} · ${category.passengers} passagers', overflow: TextOverflow.ellipsis))],
                onChanged: field ? (value) => setState(() => _vehicleTypeId = value) : null,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _motor,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Motorisation'),
                    items: [for (final entry in motors.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
                    onChanged: field ? (value) => setState(() => _motor = value ?? _motor) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _seats, enabled: field, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Places'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _color, decoration: const InputDecoration(labelText: 'Couleur')),
              const SizedBox(height: 10),
              InkWell(
                onTap: field ? _pickDate : null,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Première mise en circulation', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                  child: Text(date == null ? 'Choisir une date' : DateFormat('d MMMM yyyy', 'fr_FR').format(date)),
                ),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _rental, onChanged: field ? (v) => setState(() => _rental = v) : null, title: const Text('Véhicule en location'), subtitle: const Text('Le contrat de location est alors demandé.')),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _wifi, onChanged: (v) => setState(() => _wifi = v), title: const Text('Wifi à bord')),
              if (car != null) SwitchListTile(contentPadding: EdgeInsets.zero, value: _enabled, onChanged: (v) => setState(() => _enabled = v), title: const Text('Véhicule activé'), subtitle: const Text('Désactivez-le pour ne plus recevoir de courses avec.')),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SectionCard(color: AppColors.dangerSoft, child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(car == null ? 'Enregistrer le véhicule' : 'Enregistrer'),
          ),
          const SizedBox(height: 16),
          if (car == null)
            const SectionCard(color: AppColors.brandSoft, child: Text('Enregistrez le véhicule pour ajouter ensuite sa carte grise, son assurance et sa photo.'))
          else ...[
            for (final spec in carDocuments(rental: car.rental)) ...[
              DocumentCard(
                spec: spec,
                files: car.documents.where((d) => d.kind == spec.kind).toList(),
                missing: car.documentsMissing.contains(spec.kind),
                locked: car.locked,
                busy: _busyKind == spec.kind,
                disabled: _busyKind != null,
                onAdd: () => _add(spec),
                onRemove: _remove,
              ),
              const SizedBox(height: 12),
            ],
            if (!car.locked) TextButton.icon(style: TextButton.styleFrom(foregroundColor: AppColors.danger), onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('Supprimer ce véhicule')),
          ],
        ]),
      ),
    );
  }
}
