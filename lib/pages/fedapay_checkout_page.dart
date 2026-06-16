// lib/pages/fedapay_checkout_page.dart
// Page WebView intégrée pour le paiement FedaPay (MoMo + Carte)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/fedapay_service.dart';
import '../l10n/app_localizations.dart';

class FedaPayCheckoutPage extends StatefulWidget {
  final String checkoutUrl;
  final String transactionId;
  final String orderId;

  const FedaPayCheckoutPage({
    super.key,
    required this.checkoutUrl,
    required this.transactionId,
    required this.orderId,
  });

  @override
  State<FedaPayCheckoutPage> createState() => _FedaPayCheckoutPageState();
}

class _FedaPayCheckoutPageState extends State<FedaPayCheckoutPage> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _pageLoading = true;
  bool _checking = false;
  bool _isPending = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // User-agent navigateur standard pour que FedaPay charge correctement
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _pageLoading = true),
        onPageFinished: (_) => setState(() => _pageLoading = false),
        onWebResourceError: (err) {
          debugPrint(
              '[WebView] Erreur ressource : ${err.description} (${err.errorCode})');
        },
        onNavigationRequest: (req) {
          debugPrint('[WebView] Navigation ? ${req.url}');
          final url = req.url.toLowerCase();
          if (url.contains('success') ||
              url.contains('approved') ||
              url.contains('complete')) {
            _verifyAndClose();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    // Polling automatique toutes les 6 secondes
    _pollTimer =
        Timer.periodic(const Duration(seconds: 6), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Polling silencieux (ne modifie pas l'UI sauf si payé)
  Future<void> _pollStatus() async {
    if (_checking || !mounted) return;
    try {
      final res = await FedaPayService.getTransaction(widget.transactionId);
      if (!mounted) return;
      final status = res['status'] as String? ?? '';
      if (status == 'approved') {
        _pollTimer?.cancel();
        Navigator.of(context)
            .pop({'success': true, 'transactionId': widget.transactionId});
      } else if (status == 'declined' || status == 'canceled') {
        _pollTimer?.cancel();
        Navigator.of(context).pop({
          'success': false,
          'message': AppLocalizations.of(context).paymentDeclined,
        });
      }
    } catch (_) {}
  }

  // Vérification manuelle (bouton "J'ai payé")
  Future<void> _verifyAndClose() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _isPending = false;
      _statusMsg = AppLocalizations.of(context).verificationInProgress;
    });

    try {
      final res = await FedaPayService.getTransaction(widget.transactionId);
      if (!mounted) return;
      final status = res['status'] as String? ?? '';

      if (status == 'approved') {
        _pollTimer?.cancel();
        Navigator.of(context)
            .pop({'success': true, 'transactionId': widget.transactionId});
        return;
      }

      final t = AppLocalizations.of(context);
      setState(() {
        _checking = false;
        _isPending = status == 'pending';
        _statusMsg = _isPending
            ? t.paymentPendingConfirm
            : t.statusRetry(status);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _isPending = false;
        _statusMsg = AppLocalizations.of(context).verificationError;
      });
    }
  }

  void _cancel() {
    _pollTimer?.cancel();
    Navigator.of(context).pop({
      'success': false,
      'message': AppLocalizations.of(context).paymentCancelledMsg,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _cancel,
          tooltip: AppLocalizations.of(context).cancel,
        ),
        title: Row(children: [
          Image.network(
            'https://i.ibb.co/jZQYXrCy/logoallofood.png',
            height: 22,
            errorBuilder: (_, __, ___) => const Text('FedaPay',
                style: TextStyle(color: Colors.black87, fontSize: 15)),
          ),
        ]),
        actions: [
          if (_pageLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.orange),
                ),
              ),
            ),
        ],
        bottom: _pageLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      body: Column(children: [
        // WebView principal
        Expanded(child: WebViewWidget(controller: _controller)),

        // Barre du bas — statut + bouton
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Message de statut
            if (_statusMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(
                    _isPending
                        ? Icons.info_outline
                        : Icons.warning_amber_outlined,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMsg,
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ]),
              ),

            // Bouton principal "J'ai confirmé"
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _checking ? null : _verifyAndClose,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Builder(builder: (ctx) {
                  final t = AppLocalizations.of(ctx);
                  return Text(
                    _checking ? t.verifying : t.verifyPayment,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  );
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Fallback : page blanche ? ouvrir dans Chrome
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(AppLocalizations.of(context).emptyPage,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(widget.checkoutUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  AppLocalizations.of(context).openInBrowser,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
