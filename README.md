# App client TonVTC (Flutter)

App de réservation des clients. Les étapes sont les mêmes que sur le site :
1. **Trajet** : adresses, date, aller simple ou aller-retour. Un trajet hors forfait est refusé dès cette étape.
2. **Véhicule** : choix de l'offre, sièges enfant.
3. **Coordonnées** : reprises du compte, plus le vol / train et la pancarte pour un aéroport ou une gare, le code promo et l'avoir.
4. **Confirmation.**

Un **compte est obligatoire** pour réserver : connexion avec Google ou par e-mail. Les prix et les adresses restent consultables sans compte. « Confirmer la réservation » reste désactivé tant qu'il manque le prénom, le nom, l'e-mail ou le téléphone. Les coordonnées saisies sont enregistrées sur le compte.

Autres onglets :
- **Mes courses** : à venir et passées ; le détail montre le chauffeur et permet d'annuler, avec les frais annoncés avant.
- **Compte** : coordonnées.

## Lancer l'app

Les prérequis sont les mêmes que pour l'app chauffeur (voir `../gs-vtc-driver/README.md`).

```bash
export PATH=~/development/flutter/bin:$PATH
# Émulateur : les valeurs par défaut (10.0.2.2 = l'ordinateur) suffisent
flutter run
# Téléphone USB : rediriger les ports puis viser localhost
adb reverse tcp:3000 tcp:3000 && adb reverse tcp:3001 tcp:3001
flutter run --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=SITE_URL=http://localhost:3001
```

L'app n'accepte que les **comptes client** : un compte chauffeur ou admin est refusé à la connexion.

## Recherche d'adresses (Google Places)

La recherche passe par l'API (`GET /api/v1/places`), qui utilise la clé `API_GOOGLE` de son `.env` (à défaut `GOOGLE_MAPS_API_KEY`). La clé n'est jamais dans l'app. **Places API (New)** doit être activée dans le projet Google Cloud de cette clé. Après une modification du `.env`, il faut redémarrer l'API (`bin/rails restart`).

## Connexion Google

Sans configuration, le bouton affiche « Continuer avec Google (bientôt) », et la connexion par e-mail fonctionne. Pour l'activer, dans la [console Google Cloud](https://console.cloud.google.com/apis/credentials), sur le même projet :

1. Écran de consentement OAuth : type « Externe », nom « TonVTC ».
2. Créer un ID client OAuth **« Application Web »**. Son ID sert deux fois :
   - côté API : `GOOGLE_CLIENT_IDS=<id-web>` (plusieurs ID possibles, séparés par des virgules) ;
   - côté app : `--dart-define=GOOGLE_SERVER_CLIENT_ID=<id-web>`.
3. Créer un ID client OAuth **« Android »** :
   - nom de package : `com.tonvtc.gs_vtc_client` ;
   - empreinte SHA-1 de la clé de signature. Pour la clé de debug : `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`. Ajouter plus tard celle de la clé de publication.

L'app envoie le jeton Google à l'API, qui vérifie sa signature, l'audience et l'e-mail vérifié. L'API retrouve ou crée le compte client, puis ouvre une session de 30 jours renouvelée automatiquement, comme dans l'app chauffeur.

## Organisation du code

| Dossier | Rôle |
|---|---|
| `lib/api` | Client HTTP (sans jeton pour les prix et adresses, renouvellement automatique de la session) et routes utilisées |
| `lib/auth` | Connexion Google / e-mail, inscription, stockage sécurisé des jetons |
| `lib/booking` | Règles (délai de 2 h, coordonnées, total, promo et avoir) et déroulé des étapes |
| `lib/models` | Lieux, devis et offres, profil, courses |
| `lib/screens` | Réserver, recherche d'adresse, connexion, Mes courses, Compte |
| `test` | Règles de réservation et déroulé des étapes |

```bash
flutter analyze
flutter test
```
