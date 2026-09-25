/// Textes légaux officiels fournis par PROSOFT ACADEMY (09/2026).
///
/// Format du corps, interprété par l'écran de lecture :
/// - ligne « ## TITRE » → titre de section ;
/// - ligne « - élément » → puce ;
/// - autre ligne → paragraphe (une ligne vide sépare les blocs) ;
/// - « [libellé](https://…) » → lien cliquable.
typedef LegalDoc = ({String title, String updated, String body});

const legalUpdated = '09/2026';

const legalDocs = <String, LegalDoc>{
  'legal': (
    title: 'Mentions légales',
    updated: legalUpdated,
    body: '''
## 1. ÉDITEUR

MON CAR est un projet porté par :

PROSOFT ACADEMY SARL
RCCM : CI-ABJ-03-2025-B12-02110
N° CC : 2502724 F

Siège social :
Bingerville, Côte d'Ivoire

E-mail :
secretariat@prosoft-academy.net

Site web :
www.prosoft-academy.net

## 2. PRÉSENTATION DE MON CAR

MON CAR est une plateforme numérique destinée à contribuer à la modernisation et à la digitalisation du transport interurbain en Côte d'Ivoire.

La plateforme peut notamment proposer des fonctionnalités liées à :

- la réservation de voyages ;
- la billetterie électronique ;
- le paiement en ligne ;
- la gestion des compagnies de transport ;
- la gestion des gares et agences ;
- la gestion des véhicules ;
- la gestion des trajets ;
- le contrôle des passagers ;
- la gestion des bagages ;
- la géolocalisation ;
- le suivi des véhicules ;
- la gestion des manifestes.

## 3. CONCEPTION ET DÉVELOPPEMENT

La conception et le développement technique de MON CAR sont assurés par une équipe de développeurs intervenant en qualité de partenaires technologiques du projet.

Équipe de conception et développement :

ALLE SOUROU MARCEL — [marcelalle.is-a.dev](https://marcelalle.is-a.dev)
Développeur Web et Mobile
Partenaire technologique

SHARTY TARIQ RICHARD
Développeur Web et Mobile
Partenaire technologique

## 4. PROPRIÉTÉ INTELLECTUELLE

Les éléments composant MON CAR, notamment son interface, son identité visuelle, ses contenus, ses logiciels, ses bases de données, ses développements spécifiques et ses éléments graphiques, sont protégés conformément aux droits applicables.

Toute reproduction, modification, représentation ou exploitation non autorisée de tout ou partie de ces éléments est interdite.

## 5. DONNÉES PERSONNELLES

MON CAR peut collecter et traiter certaines données personnelles nécessaires au fonctionnement de ses services.

Selon les fonctionnalités utilisées, ces données peuvent notamment comprendre :

- les informations d'identification ;
- les coordonnées de contact ;
- les informations relatives au compte ;
- les informations relatives aux réservations ;
- les informations relatives aux trajets ;
- les informations nécessaires au paiement ;
- les données de localisation lorsque cette fonctionnalité est activée ;
- certaines données techniques nécessaires au fonctionnement et à la sécurité de la plateforme.

Les données sont traitées conformément à la réglementation applicable en matière de protection des données personnelles.

## 6. GÉOLOCALISATION

Certaines fonctionnalités de MON CAR peuvent utiliser la géolocalisation.

Elle peut notamment être utilisée pour :

- localiser un véhicule ;
- suivre un trajet ;
- faciliter certaines opérations de transport ;
- améliorer la sécurité ;
- fournir des informations liées au trajet.

L'utilisation de la géolocalisation dépend des autorisations accordées par l'utilisateur et des fonctionnalités utilisées.

## 7. SÉCURITÉ

MON CAR met en œuvre des mesures techniques et organisationnelles destinées à protéger les données et les informations utilisées par la plateforme contre les accès non autorisés, la perte, la modification ou l'utilisation frauduleuse.

## 8. SERVICES TIERS

Certaines fonctionnalités peuvent utiliser des services fournis par des prestataires tiers, notamment pour :

- l'hébergement ;
- l'authentification ;
- le stockage ;
- les notifications ;
- les SMS ;
- les paiements ;
- la cartographie ;
- la géolocalisation ;
- la sécurité et l'analyse technique.

Ces services peuvent être soumis à leurs propres conditions d'utilisation et politiques de confidentialité.

## 9. DISPONIBILITÉ DU SERVICE

MON CAR met en œuvre les moyens nécessaires pour assurer la disponibilité de la plateforme.

Des interruptions peuvent toutefois survenir notamment en raison de maintenances, mises à jour, problèmes techniques, défaillances de réseau ou indisponibilité de services tiers.

## 10. ÉVOLUTION DE LA PLATEFORME

MON CAR peut être régulièrement mis à jour et amélioré.

Certaines fonctionnalités peuvent être ajoutées, modifiées, suspendues ou supprimées afin d'assurer l'évolution et le bon fonctionnement du service.

## 11. MARQUE ET IDENTITÉ VISUELLE

Le nom MON CAR, son logo, son identité visuelle et les éléments graphiques associés sont protégés conformément aux droits applicables.

Toute utilisation non autorisée est interdite.

## 12. MODIFICATION DES MENTIONS LÉGALES

Les présentes mentions légales peuvent être mises à jour en fonction de l'évolution de MON CAR, de ses services ou de la réglementation applicable.

La version publiée sur la plateforme constitue la version en vigueur.

## 13. DROIT APPLICABLE

Les présentes mentions légales sont soumises au droit applicable en République de Côte d'Ivoire, sous réserve des dispositions impératives applicables.

## 14. CONTACT

Pour toute question concernant MON CAR ou les présentes mentions légales :

PROSOFT ACADEMY SARL

E-mail :
secretariat@prosoft-academy.net

Site web :
www.prosoft-academy.net''',
  ),
  'privacy': (
    title: 'Politique de confidentialité',
    updated: legalUpdated,
    body: '''
## 1. OBJET

La présente Politique de confidentialité explique comment MON CAR collecte, utilise, protège et conserve les données personnelles dans le cadre de l'utilisation de ses services.

## 2. RESPONSABLE

Le projet MON CAR est porté par :

PROSOFT ACADEMY SARL
RCCM : CI-ABJ-03-2025-B12-02110
N° CC : 2502724 F

Siège social :
Bingerville Oribat, à 100 mètres du siège du COSIM,
République de Côte d'Ivoire.

E-mail :
secretariat@prosoft-academy.net

## 3. DONNÉES COLLECTÉES

Selon les fonctionnalités utilisées, MON CAR peut collecter :

- nom et prénom ;
- numéro de téléphone ;
- adresse e-mail ;
- informations du compte ;
- informations relatives aux réservations ;
- informations relatives aux trajets ;
- informations relatives aux véhicules ;
- informations relatives aux paiements ;
- données de localisation ;
- informations techniques ;
- informations nécessaires à la sécurité du compte.

## 4. UTILISATION DES DONNÉES

Les données collectées peuvent être utilisées pour :

- créer et gérer les comptes ;
- authentifier les utilisateurs ;
- permettre les réservations ;
- gérer les billets ;
- faciliter les paiements ;
- suivre certains trajets ;
- assurer la géolocalisation lorsque celle-ci est activée ;
- assurer la sécurité de la plateforme ;
- prévenir les fraudes ;
- fournir une assistance ;
- améliorer les services ;
- assurer la maintenance technique.

## 5. GÉOLOCALISATION

Lorsque l'utilisateur autorise la géolocalisation, MON CAR peut utiliser les données de localisation nécessaires aux fonctionnalités concernées.

Ces données peuvent notamment permettre :

- le suivi d'un véhicule ;
- le suivi d'un trajet ;
- la localisation nécessaire à une prise en charge ;
- certaines fonctions de sécurité ;
- l'affichage d'informations liées au trajet.

L'utilisateur peut gérer les autorisations de localisation depuis les paramètres de son appareil.

## 6. PARTAGE DES DONNÉES

Les données peuvent être accessibles aux personnes ou prestataires qui en ont besoin pour assurer les services de MON CAR.

Il peut notamment s'agir :

- des équipes autorisées de MON CAR ;
- des compagnies de transport concernées ;
- des prestataires de paiement ;
- des prestataires d'hébergement ;
- des prestataires techniques ;
- des services de notification ;
- des services de cartographie ou de géolocalisation ;
- des autorités compétentes lorsque la loi l'exige.

## 7. SERVICES TIERS

MON CAR peut utiliser des services techniques fournis par des entreprises tierces.

Ces services peuvent notamment concerner :

- l'authentification ;
- le stockage ;
- les bases de données ;
- les notifications ;
- les SMS ;
- les paiements ;
- la cartographie ;
- la géolocalisation ;
- l'analyse et la sécurité.

Chaque service tiers peut être soumis à sa propre politique de confidentialité.

## 8. CONSERVATION DES DONNÉES

Les données personnelles sont conservées pendant une durée adaptée aux finalités pour lesquelles elles sont utilisées et conformément aux obligations légales applicables.

Certaines données peuvent être conservées pendant la durée nécessaire à la gestion d'un compte, d'une réservation, d'une transaction ou d'une obligation légale.

## 9. SÉCURITÉ

MON CAR met en œuvre des mesures techniques et organisationnelles destinées à protéger les données personnelles.

Ces mesures peuvent notamment comprendre :

- la gestion des accès ;
- l'authentification ;
- le chiffrement lorsque nécessaire ;
- la sécurisation des communications ;
- la sauvegarde ;
- la surveillance technique ;
- la limitation des accès aux seules personnes autorisées.

## 10. DROITS DES UTILISATEURS

Conformément à la réglementation applicable en matière de protection des données personnelles, les utilisateurs peuvent disposer de droits concernant leurs données.

Ces droits peuvent notamment comprendre :

- le droit à l'information ;
- le droit d'accès ;
- le droit de rectification ;
- le droit d'opposition ;
- le droit de suppression ou d'effacement, lorsque les conditions applicables sont réunies.

## 11. EXERCICE DES DROITS

Pour toute demande concernant les données personnelles, l'utilisateur peut contacter :

PROSOFT ACADEMY SARL

E-mail :
secretariat@prosoft-academy.net

La demande doit permettre d'identifier raisonnablement le compte ou les données concernés.

## 12. SÉCURITÉ DU COMPTE

L'utilisateur est responsable de la confidentialité de ses identifiants.

Il doit notamment :

- utiliser un mot de passe suffisamment sécurisé lorsque cette fonctionnalité est proposée ;
- ne pas communiquer ses identifiants ;
- signaler rapidement toute activité suspecte ;
- se déconnecter d'un appareil partagé lorsque cela est nécessaire.

## 13. MODIFICATION DE LA POLITIQUE

La présente Politique de confidentialité peut être modifiée afin de tenir compte de l'évolution de MON CAR, des services utilisés ou de la réglementation applicable.

La version publiée sur la plateforme constitue la version en vigueur.''',
  ),
  // TODO(A-13): texte provisoire hérité du prototype, NON validé par
  // PROSOFT — à remplacer par les CGU officielles.
  'terms': (
    title: "Conditions d'utilisation",
    updated: 'provisoire',
    body:
        "En utilisant MON CAR, vous acceptez les présentes conditions. Vous certifiez avoir 18 ans révolus ou disposer d'une autorisation parentale. Les réservations sont confirmées uniquement après paiement serveur à l'état « payé ». Les tarifs affichés sont fermes et calculés par le serveur. En cas d'annulation, le remboursement suit la politique de la compagnie (Flexible, Modéré, Strict). Les litiges sont à signaler sous 48h.",
  ),
  'credits': (
    title: 'Crédits',
    updated: legalUpdated,
    body: '''
MON CAR est un projet porté par PROSOFT ACADEMY.

## CONCEPTION ET DÉVELOPPEMENT

ALLE SOUROU MARCEL — [marcelalle.is-a.dev](https://marcelalle.is-a.dev)
Développeur Web et Mobile
Partenaire technologique

SHARTY TARIQ RICHARD
Développeur Web et Mobile
Partenaire technologique

## ÉQUIPE TECHNIQUE

L'équipe technique contribue à la conception, au développement, à la maintenance, à la sécurisation et à l'évolution de la plateforme MON CAR.''',
  ),
};
