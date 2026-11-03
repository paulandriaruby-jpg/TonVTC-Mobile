# App chauffeur (Flutter)

App des chauffeurs partenaires. Elle permet de :
- se connecter ;
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
| `lib/models` | Propositions, courses (et leur étape), gains, relevés, profil |
| `lib/screens` | Connexion, Courses (propositions / à venir / historique), détail d'une course, Gains, Profil |
| `test` | Client API, modèles et formats, écran de connexion |

```bash
flutter analyze
flutter test
```
