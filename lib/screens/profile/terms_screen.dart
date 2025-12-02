import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Conditions Générales",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                _cguText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6, // Espacement des lignes pour la lisibilité
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              // Bouton "J'ai compris" optionnel en bas de page
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Retour", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Le texte est stocké ici pour garder le widget propre
const String _cguText = '''
CONDITIONS GÉNÉRALES D'UTILISATION (CGU) - PUBCASH

Dernière mise à jour : [Date du jour]

1. MENTIONS LÉGALES
L'application mobile et la plateforme web Pubcash (ci-après dénommées "la Plateforme") sont éditées et exploitées par la société KKS-TECHNOLOGIES.

• Dénomination sociale : KKS-TECHNOLOGIES
• Site web officiel : https://kks-technologies.com/
• Siège social : [Insérer votre adresse physique ici]
• Email de contact : [Insérer votre email support]

2. OBJET
Les présentes CGU ont pour objet de définir les modalités de mise à disposition des services de la Plateforme Pubcash, qui connecte :
1. Des Promoteurs (via l'interface Web) souhaitant diffuser du contenu publicitaire.
2. Des Utilisateurs (via l'application Mobile) acceptant de visionner ce contenu en échange de points convertibles.

Toute inscription ou utilisation de la Plateforme implique l'acceptation sans réserve des présentes CGU.

3. ACCÈS ET INSCRIPTION

3.1. Conditions d'accès
L'Utilisateur doit être une personne physique âgée d'au moins [18] ans.
L'Utilisateur doit disposer d'un numéro de téléphone mobile valide pour la validation du compte.

3.2. Compte Unique
Il est strictement interdit de créer plusieurs comptes pour une même personne physique. La règle est : 1 Personne = 1 Appareil = 1 Compte.
KKS-TECHNOLOGIES se réserve le droit d'utiliser des technologies d'empreinte numérique (Device ID) pour détecter les comptes multiples.

4. FONCTIONNEMENT DES GAINS (POINTS ET RÉCOMPENSES)

4.1. Acquisition de Points
L'Utilisateur gagne des points en visionnant intégralement des publicités ou en accomplissant des tâches spécifiques.
KKS-TECHNOLOGIES ne garantit pas la disponibilité permanente de publicités.
Les points n'ont aucune valeur monétaire intrinsèque tant qu'ils n'ont pas atteint le seuil de retrait et été convertis.

4.2. Taux de Conversion
Le taux de conversion (Nombre de points = X FCFA) est défini unilatéralement par KKS-TECHNOLOGIES et peut être modifié à tout moment en fonction des revenus publicitaires globaux, sans effet rétroactif sur les points déjà convertis en demande de retrait.

5. PAIEMENTS ET RETRAITS

5.1. Seuil de Paiement
Le paiement des gains est conditionné à l'atteinte d'un seuil minimum clairement indiqué dans l'application.

5.2. Modalités et Délais
Les paiements sont effectués via les services de Mobile Money (Wave, Orange Money, MTN MoMo, etc.) disponibles en Côte d'Ivoire.
L'Utilisateur est seul responsable de l'exactitude du numéro de téléphone fourni pour le paiement.
Délai : KKS-TECHNOLOGIES s'efforce de traiter les demandes sous [3 à 7] jours ouvrés. Ce délai est indicatif et peut être allongé en cas de vérifications anti-fraude.

6. POLITIQUE ANTI-FRAUDE ET COMPORTEMENTS INTERDITS

Pour protéger l'écosystème Pubcash et ses Promoteurs, les comportements suivants entraînent la suspension immédiate et définitive du compte, ainsi que l'annulation de tous les gains (solde du portefeuille) :

1. Usage de VPN, Proxy ou tout outil masquant l'adresse IP réelle.
2. Usage d'émulateurs Android/iOS (ex: Bluestacks, Nox) sur PC.
3. Usage d'autoclickers, scripts, bots ou tout automatisme.
4. Usage d'appareils "rootés" ou "jailbreakés" visant à contourner la sécurité.
5. Création de multiples comptes pour accumuler des gains frauduleusement.

KKS-TECHNOLOGIES se réserve le droit d'engager des poursuites pénales en cas de fraude avérée portant préjudice à l'entreprise.

7. RESPONSABILITÉS

7.1. Contenu Publicitaire (Pour les Promoteurs)
Les Promoteurs sont seuls responsables du contenu (images, textes, liens) qu'ils diffusent. Il est strictement interdit de promouvoir :
• Des contenus illégaux, diffamatoires ou haineux.
• De la pornographie ou des contenus pour adultes.
• Des arnaques financières ou systèmes pyramidaux.
KKS-TECHNOLOGIES se réserve le droit de refuser ou supprimer toute campagne sans remboursement si elle viole ces règles.

7.2. Limitation de responsabilité
KKS-TECHNOLOGIES ne saurait être tenu responsable :
• Des dysfonctionnements du réseau internet ou des services de Mobile Money.
• De la non-disponibilité momentanée de l'application pour maintenance.
• Des dommages directs ou indirects causés par l'utilisation de l'application.

8. DONNÉES PERSONNELLES
KKS-TECHNOLOGIES s'engage à traiter les données personnelles (numéro de téléphone, identifiant unique, données de navigation) conformément aux lois en vigueur en Côte d'Ivoire.
Ces données sont utilisées pour :
1. La gestion du compte et des paiements.
2. La lutte contre la fraude.
3. Le ciblage publicitaire (anonymisé).

9. MODIFICATION ET RÉSILIATION
KKS-TECHNOLOGIES peut modifier les présentes CGU à tout moment. L'utilisation continue de l'application vaut acceptation des nouvelles règles.
KKS-TECHNOLOGIES se réserve le droit de fermer le service Pubcash avec un préavis raisonnable, en permettant aux utilisateurs d'effectuer leurs derniers retraits si le seuil est atteint.

10. DROIT APPLICABLE ET JURIDICTION
Les présentes CGU sont soumises au droit ivoirien. En cas de litige non résolu à l'amiable, compétence exclusive est attribuée aux tribunaux d'Abidjan.
''';