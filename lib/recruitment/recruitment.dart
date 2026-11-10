// Parcours de recrutement (mêmes étapes que le site) : étape actuelle et ce qu'il reste à fournir.

const validationSteps = ['identified', 'data_collected', 'files_collected', 'validated_awaiting', 'validated'];

// Numéro de l'étape sur 5 : 2/5 "identifié" ... 5/5 "validé, en attente de première activation" ; "validé" = terminé.
int stepNumber(String status) => switch (status) {
  'identified' => 2,
  'data_collected' => 3,
  'files_collected' => 4,
  _ => 5,
};

String stepTitle(String status) => switch (status) {
  'identified' => 'Compléter vos informations',
  'data_collected' => 'Ajouter vos documents',
  'files_collected' => 'Documents reçus : vérification en cours',
  'validated_awaiting' => 'Dossier validé : activation en cours',
  _ => 'Dossier validé',
};

// Dossier complet côté chauffeur : l'équipe vérifie (4/5) ou active le compte (5/5).
bool waitingForTeam(String status) => status == 'files_collected' || status == 'validated_awaiting';

const _labels = {
  // Informations
  'legal_status': 'Statut juridique',
  'address': 'Adresse',
  'postcode': 'Code postal',
  'city': 'Ville',
  'iban': 'IBAN',
  'siret': 'SIRET',
  'business_name': 'Nom de la société',
  'rcs_code': 'Numéro RCS',
  'share_capital': 'Capital social',
  // Pièces
  'identity': 'Pièce d\'identité',
  'driving_license': 'Permis de conduire',
  'vtc_card': 'Carte professionnelle VTC',
  'company_registration': 'Extrait Kbis',
  'identity_type': 'Type de pièce d\'identité',
  'identity_expiry': 'Date de fin de validité de la pièce d\'identité',
  'vtc_card_number': 'Numéro de carte VTC',
  'vtc_expiry': 'Date de fin de validité de la carte VTC',
  'car': 'Un véhicule avec ses documents',
  'photo': 'Votre photo (montrée aux clients)',
};

String missingLabel(String key) => _labels[key] ?? key;

const legalStatuses = {'self_employed': 'Auto-entrepreneur', 'company': 'Société', 'taxi': 'Taxi'};

// Contrôles avant l'envoi (le serveur vérifie aussi la clé de l'IBAN et du SIRET) ; renvoie le premier message d'erreur.
String? detailsError({
  required String legalStatus,
  required String address,
  required String postcode,
  required String city,
  required String iban,
  required String siret,
  required String businessName,
  required String rcsCode,
  required String shareCapital,
}) {
  if (address.trim().isEmpty || postcode.trim().isEmpty || city.trim().isEmpty) return 'Indiquez votre adresse complète.';
  if (!RegExp(r'^[0-9A-Za-z -]{3,10}$').hasMatch(postcode.trim())) return 'Code postal invalide.';
  if (!RegExp(r'^\d{14}$').hasMatch(siret.replaceAll(' ', ''))) return 'Le SIRET contient 14 chiffres.';
  if (iban.replaceAll(' ', '').length < 14) return 'Indiquez votre IBAN.';
  if (legalStatus != 'self_employed') {
    if (businessName.trim().isEmpty || rcsCode.trim().isEmpty) return 'Indiquez le nom de la société et la ville du RCS.';
    final capital = double.tryParse(shareCapital.replaceAll(',', '.'));
    if (capital == null || capital < 0) return 'Indiquez le capital social.';
  }
  return null;
}

// Pièces personnelles : titre, nombre de fichiers demandés (recto / verso) et contenu attendu.
class DocumentSpec {
  const DocumentSpec(this.kind, this.title, this.hint, this.max);

  final String kind;
  final String title;
  final String hint;
  final int max;
}

const identityDocument = DocumentSpec('identity', 'Pièce d\'identité', 'Recto et verso, ou la page photo du passeport.', 2);
const licenseDocument = DocumentSpec('driving_license', 'Permis de conduire', 'Recto et verso.', 2);
const vtcCardDocument = DocumentSpec('vtc_card', 'Carte professionnelle VTC', 'Recto et verso.', 2);
const companyDocument = DocumentSpec('company_registration', 'Extrait Kbis', 'Document de moins de 3 mois.', 1);

const identityTypes = {'national_identity_card': 'Carte nationale d\'identité', 'passport': 'Passeport', 'residency_card': 'Titre de séjour'};

// Le Kbis n'est demandé qu'aux sociétés et aux taxis (pas aux auto-entrepreneurs).
List<DocumentSpec> personalDocuments(String legalStatus) => [identityDocument, licenseDocument, vtcCardDocument, if (legalStatus != 'self_employed') companyDocument];

// Taille lisible d'un fichier envoyé ("1,2 Mo").
String fileSize(int bytes) => bytes >= 1048576 ? '${(bytes / 1048576).toStringAsFixed(1).replaceAll('.', ',')} Mo' : '${(bytes / 1024).ceil()} Ko';

const carRegistrationDocument = DocumentSpec('car_registration', 'Carte grise', 'Recto et verso.', 2);
const carInsuranceDocument = DocumentSpec('car_insurance', 'Attestation d\'assurance', 'En cours de validité.', 1);
const carPictureDocument = DocumentSpec('car_picture', 'Photo du véhicule', 'Vue de trois quarts avant, plaque visible.', 1);
const carRentalDocument = DocumentSpec('car_rental_contract', 'Contrat de location', 'Pour un véhicule loué.', 1);

List<DocumentSpec> carDocuments({required bool rental}) => [carRegistrationDocument, carInsuranceDocument, carPictureDocument, if (rental) carRentalDocument];

const motors = {'gas': 'Thermique', 'hybrid': 'Hybride', 'electric': 'Électrique'};

// Contrôles avant l'envoi d'un véhicule (le serveur vérifie aussi le format de la plaque et son unicité).
String? carError({required String brand, required String model, required String plate, required int? vehicleTypeId, required String seats}) {
  if (brand.trim().isEmpty || model.trim().isEmpty) return 'Indiquez la marque et le modèle.';
  if (plate.trim().length < 4) return 'Indiquez l\'immatriculation.';
  if (vehicleTypeId == null) return 'Choisissez la catégorie du véhicule.';
  final count = int.tryParse(seats.trim());
  if (seats.trim().isNotEmpty && (count == null || count < 1 || count > 20)) return 'Nombre de places invalide.';
  return null;
}
