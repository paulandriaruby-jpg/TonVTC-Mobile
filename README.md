# App chauffeur (Flutter)

App des chauffeurs partenaires. Elle permet de :
- se connecter ;
- compléter son dossier de recrutement (informations, documents, véhicule) tant qu'il n'est pas validé ;
- accepter ou refuser les courses proposées ;
- suivre chaque course (en route, arrivé, démarrée, terminée) avec l'itinéraire et l'appel du client ;
- suivre ses gains et ses relevés mensuels ;
- se déclarer disponible ou non ;
- recevoir des notifications : nouvelle course et rappel la veille.

Le nom de l'app n'est pas encore choisi : elle s'appelle « Chauffeur » pour l'instant (voir `lib/config.dart` et `android/app/src/main/AndroidManifest.xml`).

## Prérequis (déjà installés sur le poste de développement)

- Flutter (stable) : `~/development/flutter/bin`
- SDK Android : `~/Android/Sdk`
- JDK 17 pour Gradle : `~/development/jdk-17` (configuré avec `flutter config --jdk-dir`)

```bash
export PATH=~/development/flutter/bin:$PATH
flutter doctor
```

## Lancer l'app sur un téléphone Android

1. Sur le téléphone : activer les **Options pour les développeurs**, puis le **Débogage USB**, et le brancher en USB.
2. Lancer l'API pour qu'elle soit joignable depuis le réseau local : `cd ../gs-vtc-api && bin/rails s -b 0.0.0.0`
3. Trouver l'adresse IP de l'ordinateur (`hostname -I`), par exemple `192.168.1.20`.
4. Lancer l'app :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000 --dart-define=SITE_URL=http://192.168.1.20:3001
```

Sur l'émulateur Android, les valeurs par défaut (`10.0.2.2`, c'est-à-dire l'ordinateur) suffisent : `flutter run`.

Pour fabriquer un APK à installer à la main :

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.20:3000
# → build/app/outputs/flutter-apk/app-debug.apk
```

L'app ne fonctionne qu'avec un **compte chauffeur** : les autres comptes sont refusés à la connexion.

## Notifications (Firebase Cloud Messaging)

Sans Firebase, l'app fonctionne entièrement, mais sans notifications. Le profil indique alors « Notifications indisponibles ». Pour les activer :

1. Créer un projet sur <https://console.firebase.google.com>, gratuit.
2. **Ajouter une app Android** avec le nom de package `com.tonvtc.gs_vtc_driver`. Télécharger `google-services.json` et le placer dans `android/app/`. Il est ignoré par git ; l'app le prend en compte automatiquement à la compilation suivante.
3. **Côté API** : Paramètres du projet → Comptes de service → « Générer une nouvelle clé privée ». Donner le fichier JSON à l'API, soit son chemin, soit son contenu :

```bash
FCM_CREDENTIALS=/chemin/vers/compte-de-service.json bin/rails s -b 0.0.0.0
```

Ce fichier est **secret** : ne jamais le committer.

4. Relancer l'app, se connecter et accepter les notifications. Le jeton du téléphone est enregistré sur la session.

Canaux Android :
- « Nouvelles courses » : priorité maximale, son ;
- « Rappels de course ».

Chaque chauffeur peut les régler dans les paramètres du téléphone.

## Dossier de recrutement dans l'app

Un chauffeur qui n'est pas encore « Validé » se connecte à l'app, mais Courses et Gains lui expliquent que son dossier est en cours. Son **profil** affiche la fiche « Dossier de recrutement » : l'étape sur 5 (2/5 à 5/5), ce qu'il reste à fournir, et trois boutons.

| Bouton | Contenu |
|---|---|
| Mes informations | Statut juridique (auto-entrepreneur, société, taxi), SIRET, adresse, IBAN ; nom, RCS et capital hors auto-entrepreneur |
| Mes documents | Pièce d'identité (type, date de fin), permis, carte VTC (numéro, date de fin), Kbis hors auto-entrepreneur. Photo, galerie ou PDF, 8 Mo maximum |
| Mon véhicule | Marque, modèle, immatriculation, catégorie, motorisation… puis carte grise, assurance, photo (et contrat si loué) |

- Le dossier avance seul : 3/5 quand les informations sont complètes, 4/5 quand les pièces et un véhicule aux documents complets sont reçus. L'équipe valide ensuite depuis le site (5/5, puis « Validé »).
- **À 5/5**, les informations et les pièces personnelles sont en lecture seule (le serveur les refuse aussi) ; le chauffeur peut encore ajouter ou changer de véhicule. Un véhicule validé n'est plus modifiable, sauf l'activation, la couleur et le wifi.
- L'inscription d'un nouveau chauffeur reste sur le site (`/devenir-chauffeur`) ; l'app sert à compléter le dossier avec le même compte. Tout passe par les routes déjà utilisées par le site : `GET/PATCH /profile`, `POST/DELETE /profile/documents`, `GET/POST/PATCH/DELETE /profile/cars`, `GET /vehicle_types`.
- Les photos sont réduites à 2200 px avant l'envoi ; le serveur vérifie le type réel du fichier (PDF, JPEG, PNG ou WebP).
- Android : l'appareil photo et la galerie passent par le sélecteur du système, sans permission à déclarer.

## Session

- **Durée** : le chauffeur reste connecté **30 jours**. Ce délai se prolonge à chaque utilisation, et le jeton d'accès de 12 h se renouvelle tout seul.
- **Indépendante du site** : se déconnecter du site ne déconnecte pas l'app, et inversement. Le bouton « Se déconnecter de ce téléphone » ne ferme que la session de l'appareil.
- **Stockage** : les jetons sont gardés dans le coffre sécurisé du téléphone (Keystore).

## Organisation du code

| Dossier | Rôle |
|---|---|
| `lib/api` | Client HTTP (renouvellement automatique de la session) et routes utilisées |
| `lib/auth` | Connexion, déconnexion, stockage sécurisé des jetons |
| `lib/push` | Firebase Messaging, canaux Android, ouverture de la course depuis une notification |
| `lib/models` | Propositions, courses (et leur étape), gains, relevés, profil, dossier de recrutement, véhicules |
| `lib/recruitment` | Étapes et libellés du recrutement, contrôles des formulaires, choix d'un fichier (photo, galerie, PDF) |
| `lib/screens` | Connexion, Courses (propositions / à venir / historique), détail d'une course, Gains, Profil, et les écrans du dossier (informations, documents, véhicules) |
| `lib/widgets` | Éléments communs, fiche « Dossier de recrutement », carte d'une pièce justificative |
| `test` | Client API, modèles et formats, écran de connexion, dossier de recrutement (informations, documents, véhicule) |

```bash
flutter analyze
flutter test
```
