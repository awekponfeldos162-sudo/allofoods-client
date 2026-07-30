// test/unit/payment_service_confirm_test.dart
// Teste PaymentService.onPaymentSuccess — doit appeler la Cloud Function
// confirmOrderPayment avec exactement orderId + transactionId, et jamais
// écrire Firestore directement (voir firestore.rules + confirmOrderPayment
// côté serveur pour le contexte de la faille corrigée).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_2/services/payment_service.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late MockHttpsCallableResult result;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    result = MockHttpsCallableResult();
    when(() => functions.httpsCallable('confirmOrderPayment'))
        .thenReturn(callable);
    when(() => result.data).thenReturn({'success': true});
    when(() => callable.call(any())).thenAnswer((_) async => result);
  });

  test(
      'onPaymentSuccess appelle confirmOrderPayment avec exactement '
      'orderId + transactionId (jamais foodAmount/deliveryFee — recalculés '
      'côté serveur depuis Firestore, jamais depuis le client)', () async {
    await PaymentService.onPaymentSuccess(
      orderId: 'order-1',
      txId: 'tx-1',
      foodAmount: 5000,
      deliveryFee: 1000,
      functions: functions,
    );

    verify(() => functions.httpsCallable('confirmOrderPayment')).called(1);
    final captured = verify(() => callable.call(captureAny())).captured;
    expect(captured.single, {'orderId': 'order-1', 'transactionId': 'tx-1'});
  });

  test('propage l\'erreur si la Cloud Function rejette la confirmation '
      '(ex : paiement non approuvé côté FedaPay)', () async {
    when(() => callable.call(any())).thenThrow(Exception('failed-precondition'));

    expect(
      () => PaymentService.onPaymentSuccess(
        orderId: 'order-1',
        txId: 'tx-1',
        foodAmount: 1000,
        deliveryFee: 100,
        functions: functions,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
