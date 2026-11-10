import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../booking/recent_places.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Recherche d'une adresse (suggestions Google Places renvoyées par l'API). Renvoie le lieu choisi.
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key, required this.title, this.initialQuery});

  final String title;
  // Recherche lancée à l'ouverture (destinations fréquentes de l'accueil).
  final String? initialQuery;

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _input = TextEditingController();
  // Regroupe les frappes et le choix en une seule session Google (facturée une fois).
  final _sessionToken = List.generate(24, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  Timer? _debounce;
  List<PlaceSuggestion> _results = [];
  bool _loading = false;
  String? _error;
  final _recent = RecentPlaces();
  List<Place> _recentPlaces = [];

  @override
  void initState() {
    super.initState();
    _recent.load().then((places) {
      if (mounted) setState(() => _recentPlaces = places);
    });
    final query = widget.initialQuery;
    if (query != null && query.isNotEmpty) {
      _input.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(query));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().length < 3) return setState(() => _results = []);
      setState(() => _loading = true);
      try {
        final results = await context.read<ClientApi>().suggestions(value.trim(), _sessionToken);
        if (mounted && _input.text == value) {
          setState(() {
            _results = results;
            _error = null;
          });
        }
      } catch (error) {
        if (mounted) setState(() => _error = 'Recherche d\'adresses indisponible. Réessayez.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    setState(() => _loading = true);
    try {
      final place = await context.read<ClientApi>().place(suggestion.placeId, _sessionToken);
      await _recent.add(place);
      if (mounted) Navigator.of(context).pop(place);
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        handleError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _input,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Adresse, gare, aéroport...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
        // Champ vide : les dernières adresses choisies.
        if (_results.isEmpty && _input.text.trim().length < 3 && _recentPlaces.isNotEmpty)
          Expanded(
            child: ListView(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Adresses récentes', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted, fontSize: 13)),
              ),
              for (final place in _recentPlaces) ...[
                ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.history, color: AppColors.brand),
                  title: Text(place.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    await _recent.add(place);
                    if (context.mounted) Navigator.of(context).pop(place);
                  },
                ),
                const Divider(height: 1),
              ],
            ]),
          )
        else
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final suggestion = _results[index];
              return ListTile(
                tileColor: Colors.white,
                leading: const Icon(Icons.place_outlined, color: AppColors.brand),
                title: Text(suggestion.main, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: suggestion.secondary == null ? null : Text(suggestion.secondary!),
                onTap: () => _pick(suggestion),
              );
            },
          ),
        ),
      ]),
    );
  }
}
