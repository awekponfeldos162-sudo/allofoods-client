// lib/services/receipt_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Convertit num ou String Firestore en int
int _n(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

class ReceiptService {
  static final _orange = PdfColor.fromHex('#FF6600');
  static final _lightGrey = PdfColor.fromHex('#F8F8F8');

  // ── Reçu A4 client ──────────────────────────────────────────────────────────

  static Future<Uint8List> buildClientReceipt(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();
    final qrData = 'allofoods://order/$orderId';

    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _n(data['totalAmount']);
    final foodAmount = _n(data['foodAmount']);
    final serviceFee = _n(data['serviceFee']);
    final deliveryFee = _n(data['deliveryFee']);
    final delivCash = (data['delivery_payment_method'] as String?) == 'cash';
    final payment = data['paymentMethod'] as String? ?? '-';
    final txId = data['transactionId'] as String? ?? '';
    final restaurantName = data['restaurantName'] as String? ?? 'Restaurant';
    final address = data['deliveryAddress'] as String? ?? '-';
    final dateStr = _fmtDate(data['createdAt']);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── En-tête ───────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ALLOFOODS',
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: _orange)),
                  pw.Text('Reçu de commande',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text('N° #${orderId.substring(0, 8).toUpperCase()}',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateStr,
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey600)),
                ],
              ),
              pw.BarcodeWidget(
                data: qrData,
                barcode: pw.Barcode.qrCode(),
                width: 80,
                height: 80,
                drawText: false,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _orange, thickness: 1.5),
          pw.SizedBox(height: 12),

          // ── Détails commande ──────────────────────────────────────
          _infoRow('Restaurant', restaurantName),
          _infoRow('Adresse de livraison', address),
          pw.SizedBox(height: 16),

          // ── Tableau articles ──────────────────────────────────────
          pw.Text('Articles commandés',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(45),
              2: const pw.FixedColumnWidth(95),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _orange),
                children: [
                  _cell('Article', hdr: true),
                  _cell('Qté', hdr: true),
                  _cell('Montant', hdr: true),
                ],
              ),
              ...items.map((item) {
                final qty = _n(item['quantity']);
                final price = _n(item['price']);
                return pw.TableRow(children: [
                  _cell(item['name'] as String? ?? ''),
                  _cell('$qty'),
                  _cell('${qty * price} FCFA'),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Récapitulatif financier ────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: _lightGrey,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Column(children: [
              _amtRow('Sous-total plats', '$foodAmount FCFA'),
              _amtRow('Commission service (5%)', '$serviceFee FCFA'),
              _amtRow(
                delivCash ? 'Livraison (réglé en espèces)' : 'Livraison',
                '$deliveryFee FCFA',
              ),
              pw.Divider(color: PdfColors.grey400),
              _amtRow('TOTAL', '$total FCFA', bold: true, clr: _orange),
            ]),
          ),
          pw.SizedBox(height: 16),

          // ── Informations paiement ─────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Informations de paiement',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 6),
                _amtRow('Méthode', _payLabel(payment)),
                if (txId.isNotEmpty && txId != 'CASH')
                  _amtRow('Réf. transaction', txId),
                _amtRow('Statut', 'Paye'),
              ],
            ),
          ),
          pw.Spacer(),

          // ── Pied de page ─────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
            child: pw.Text(
              'Merci de votre confiance — AlloFoods',
              style: const pw.TextStyle(
                  color: PdfColors.grey500, fontSize: 10),
            ),
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── Ticket thermique 80 mm restaurant ───────────────────────────────────────

  static Future<Uint8List> buildRestaurantTicket(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();
    final qrData = 'allofoods://order/$orderId';

    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _n(data['totalAmount']);
    final restaurantName = data['restaurantName'] as String? ?? 'Restaurant';
    final address = data['deliveryAddress'] as String? ?? '-';
    final dateStr = _fmtDate(data['createdAt']);

    const pageWidth = 80 * PdfPageFormat.mm;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(pageWidth, double.infinity,
          marginAll: 5 * PdfPageFormat.mm),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('ALLOFOODS',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _orange)),
          pw.Text('Ticket de commande',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _dottedLine(),
          pw.SizedBox(height: 4),

          pw.Text('#${orderId.substring(0, 8).toUpperCase()}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(dateStr,
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(restaurantName,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Livraison : $address',
              style: const pw.TextStyle(
                  fontSize: 7.5, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          _dottedLine(),
          pw.SizedBox(height: 6),

          // Articles
          ...items.map((item) {
            final qty = _n(item['quantity']);
            final price = _n(item['price']);
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text('$qty x ${item['name'] ?? ''}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Text('${qty * price} F',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 4),
          _dottedLine(),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('$total FCFA',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _orange)),
            ],
          ),
          pw.SizedBox(height: 10),

          pw.Center(
            child: pw.BarcodeWidget(
              data: qrData,
              barcode: pw.Barcode.qrCode(),
              width: 72,
              height: 72,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'Scanner pour acceder a la commande',
              style: const pw.TextStyle(
                  fontSize: 7.5, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── Actions publiques ────────────────────────────────────────────────────────

  static Future<void> shareClientReceipt(
      String orderId, Map<String, dynamic> data) async {
    final bytes = await buildClientReceipt(orderId, data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'recu_allofoods_${orderId.substring(0, 8)}.pdf',
    );
  }

  static Future<void> shareRestaurantTicket(
      String orderId, Map<String, dynamic> data) async {
    final bytes = await buildRestaurantTicket(orderId, data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ticket_allofoods_${orderId.substring(0, 8)}.pdf',
    );
  }

  static Future<void> printRestaurantTicket(
      String orderId, Map<String, dynamic> data) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildRestaurantTicket(orderId, data),
      name: 'ticket_allofoods_${orderId.substring(0, 8)}',
    );
  }

  // ── Helpers privés ───────────────────────────────────────────────────────────

  static String _fmtDate(dynamic ts) {
    if (ts == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format((ts as Timestamp).toDate());
    } catch (_) {
      return '-';
    }
  }

  static pw.Widget _cell(String text, {bool hdr = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: hdr ? pw.FontWeight.bold : null,
              color: hdr ? PdfColors.white : PdfColors.black),
        ),
      );

  static pw.Widget _amtRow(String label, String value,
          {bool bold = false, PdfColor? clr}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                    fontWeight: bold ? pw.FontWeight.bold : null)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: bold ? pw.FontWeight.bold : null,
                    color: clr ?? PdfColors.black)),
          ],
        ),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text('$label : ',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ]),
      );

  static pw.Widget _dottedLine() => pw.Text(
        '- ' * 24,
        style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 7),
      );

  static String _payLabel(String p) {
    switch (p) {
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Carte bancaire';
      case 'cash':
        return 'Especes';
      default:
        return p;
    }
  }
}
