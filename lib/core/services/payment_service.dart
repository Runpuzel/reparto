import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/app_constants.dart';
import '../config/supabase_client.dart';

/// Result of a checkout attempt.
class PaymentResult {
  final bool success;
  final String? reference;
  final String? message;
  PaymentResult({required this.success, this.reference, this.message});
}

/// Drives the Paystack hosted-checkout flow through the Edge Functions.
///
/// 1. `paystack-initialize` computes the cart total server-side and returns a
///    Paystack `authorization_url` + `reference`.
/// 2. The user completes payment on Paystack's hosted page (WebView on mobile,
///    new tab on web).
/// 3. `paystack-verify` confirms the payment and places the order.
class PaymentService {
  static const String _hostedCallback =
      '${AppConstants.publicBaseUrl}/payment-complete';

  /// Runs the full checkout. On mobile, opens an in-app WebView and watches for
  /// the Paystack callback URL. On web, opens a new tab and relies on the
  /// caller to verify when the user returns.
  ///
  /// [deliveryAddress], [contactPhone] and [note] are captured server-side in
  /// the payment record and applied to the order once payment is verified.
  Future<PaymentResult> checkout(
      BuildContext context, {
        required String deliveryAddress,
        required String contactPhone,
        String? note,
        bool useTokens = false,
      }) async {
    final callbackUrl = kIsWeb
        ? Uri.base.resolve('/payment-complete').toString()
        : _hostedCallback;
    // 1. Initialize
    final initRes = await supabase.functions.invoke(
      'paystack-initialize',
      body: {
        // Paystack redirects here on completion; we just need a stable URL we
        // can detect inside the WebView.
        'callback_url': callbackUrl,
        'delivery_address': deliveryAddress,
        'contact_phone': contactPhone,
        'note': note,
        'use_tokens': useTokens,
      },
    );

    final data = initRes.data as Map?;
    if (data == null || data['authorization_url'] == null) {
      return PaymentResult(
          success: false, message: data?['error']?.toString() ?? 'Init failed');
    }
    final authUrl = data['authorization_url'] as String;
    final reference = data['reference'] as String;

    if (kIsWeb) {
      // Open Paystack in a new tab; verify when the user comes back.
      await launchUrl(Uri.parse(authUrl), webOnlyWindowName: '_blank');
      return PaymentResult(
        success: false,
        reference: reference,
        message: 'pending_web',
      );
    }

    // 2. Mobile WebView checkout
    if (!context.mounted) {
      return PaymentResult(success: false, message: 'cancelled');
    }
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PaystackWebView(
          authUrl: authUrl,
          callbackPrefix: callbackUrl,
        ),
      ),
    );

    if (completed != true) {
      return PaymentResult(
          success: false, reference: reference, message: 'cancelled');
    }

    // 3. Verify
    return verify(reference);
  }

  /// Verify a reference and place the order. Idempotent.
  Future<PaymentResult> verify(String reference) async {
    final verifyRes = await supabase.functions.invoke(
      'paystack-verify',
      body: {'reference': reference},
    );
    final v = verifyRes.data as Map?;
    if (v != null && v['status'] == 'paid') {
      return PaymentResult(success: true, reference: reference);
    }
    return PaymentResult(
      success: false,
      reference: reference,
      message: v?['message']?.toString() ?? 'Payment not completed',
    );
  }
}

/// In-app WebView that loads the Paystack checkout and pops with `true` once it
/// detects the callback URL.
class _PaystackWebView extends StatefulWidget {
  final String authUrl;
  final String callbackPrefix;
  const _PaystackWebView({required this.authUrl, required this.callbackPrefix});

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            if (req.url.startsWith(widget.callbackPrefix)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
