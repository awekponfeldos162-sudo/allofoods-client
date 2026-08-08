// integration_test/app_smoke_test.dart
//
// Tests E2E — séparés des tests unitaires (test/unit/), s'exécutent sur un
// vrai appareil/émulateur via :
//   flutter test integration_test/app_smoke_test.dart
//
// Ce fichier ne contient qu'un smoke test du harnais lui-même (le binding
// s'initialise et un widget simple se pompe sans erreur). Les parcours
// complets (connexion → commande → paiement) nécessitent un projet Firebase
// de test dédié (pas le projet de production) et seront ajoutés séparément.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le harnais integration_test démarre correctement',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('allofoods e2e'))),
    ));
    expect(find.text('allofoods e2e'), findsOneWidget);
  });
}
