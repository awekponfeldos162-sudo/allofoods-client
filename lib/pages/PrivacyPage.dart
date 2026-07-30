// lib/pages/PrivacyPage.dart
// Politique de confidentialité allofoods

import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Politique de confidentialité'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PrivacyHeader(),
          _Section(
            icon: Icons.info_outline,
            title: "1. Données collectées",
            content:
                "allofoods collecte les données suivantes :\n• Informations d'identité : nom, prénom, adresse email\n• Coordonnées : numéro de téléphone, adresse de livraison\n• Données de commandes : historique, préférences alimentaires\n• Données de paiement : numéro Mobile Money (jamais stocké en clair)\n• Données de localisation : uniquement lors de la livraison\n• Photo de profil : optionnelle, stockée sur Supabase Storage",
          ),
          _Section(
            icon: Icons.track_changes,
            title: "2. Finalités du traitement",
            content:
                "Vos données sont utilisées pour :\n• Créer et gérer votre compte utilisateur\n• Traiter et livrer vos commandes\n• Vous envoyer des notifications de statut de commande\n• Améliorer nos services et l'expérience utilisateur\n• Prévenir la fraude et assurer la sécurité\n• Respecter nos obligations légales",
          ),
          _Section(
            icon: Icons.storage,
            title: "3. Stockage et sécurité",
            content:
                "Vos données sont stockées de manière sécurisée via :\n• Firebase (Google Cloud) — authentification et base de données\n• Supabase Storage — photos de profil\n• FedaPay — transactions de paiement\n\nNous appliquons des mesures de sécurité techniques et organisationnelles pour protéger vos données contre tout accès non autorisé.",
          ),
          _Section(
            icon: Icons.share,
            title: "4. Partage des données",
            content:
                "Nous ne vendons jamais vos données personnelles. Elles peuvent être partagées avec :\n• Les restaurants partenaires (uniquement les infos nécessaires à votre commande)\n• Les livreurs (nom, adresse de livraison, téléphone)\n• Nos prestataires techniques (Firebase, Supabase Storage, FedaPay)\n• Les autorités compétentes en cas d'obligation légale",
          ),
          _Section(
            icon: Icons.timer,
            title: "5. Durée de conservation",
            content:
                "Vos données sont conservées :\n• Compte actif : pendant toute la durée d'utilisation\n• Historique de commandes : 3 ans après la dernière commande\n• Données de paiement : conformément aux obligations légales (5 ans)\n• Après suppression du compte : 30 jours puis suppression définitive",
          ),
          _Section(
            icon: Icons.gavel,
            title: "6. Vos droits",
            content:
                "Conformément à la règlementation applicable, vous disposez des droits suivants :\n• Droit d'accès à vos données\n• Droit de rectification\n• Droit à l'effacement (droit à l'oubli)\n• Droit à la portabilité\n• Droit d'opposition au traitement\n\nPour exercer ces droits, contactez : privacy@allofoods.bj",
          ),
          _Section(
            icon: Icons.location_on_outlined,
            title: "7. Localisation",
            content:
                "L'application peut accéder à votre localisation uniquement avec votre consentement explicite. Cette donnée est utilisée pour :\n• Calculer les frais de livraison\n• Permettre le suivi de votre commande\n• Suggérer des restaurants proches de vous\n\nVous pouvez désactiver la localisation à tout moment dans les paramètres de votre téléphone.",
          ),
          _Section(
            icon: Icons.notifications_outlined,
            title: "8. Notifications",
            content:
                "Nous vous envoyons des notifications push pour :\n• Confirmer vos commandes\n• Vous informer du statut de livraison\n• Vous proposer des offres personnalisées (avec votre accord)\n\nVous pouvez gérer vos préférences de notifications dans les paramètres de l'application.",
          ),
          _Section(
            icon: Icons.contact_mail_outlined,
            title: "9. Contact & réclamations",
            content:
                "Pour toute question relative à vos données personnelles :\n• Email : privacy@allofoods.bj\n• Téléphone : +229 01 47 17 49 51\n• Adresse : Cotonou, République du Bénin\n\nDernière mise à jour : Mars 2025",
          ),
        ],
      ),
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.privacy_tip_outlined,
              color: Colors.black87, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vos données nous importent',
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('allofoods s\'engage à protéger votre vie privée',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _Section(
      {required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(content,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.6)),
      ]),
    );
  }
}
