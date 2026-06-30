import 'package:flutter/material.dart';

/// Static, app-wide constants used across UjustBUY.
class AppConstants {
  static const String appName = 'UjustBUY';

  /// OAuth redirect used for Google sign-in (configure in Supabase dashboard).
  static const String oauthRedirect = 'io.reparto.app://login-callback/';

  /// Currency symbol used in price formatting.
  static const String currencySymbol = 'GH₵';

  /// App version shown on the About screen.
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // ---- Developer / publisher details ---------------------------------------
  static const String devName = 'Mr. Justice Dadzie';
  static const String devBusinessName = 'H.O.B.O Services';
  static const String devPhone = '0208223626';
  static const String devEmail = 'servizio448@gmail.com';

  /// WhatsApp link target (international format, no leading +).
  static const String devWhatsApp = '233208223626';
}

/// Order lifecycle stages — keep in sync with the `order_status` enum.
///
/// Reparto delivery flow:
///   Placed(pending) → Confirmed → Dispatched → Delivered   (+ Cancelled)
/// Legacy values (accepted/preparing/readyForPickup/completed) are still
/// understood so older rows keep working.
enum OrderStatus {
  pending,
  confirmed,
  dispatched,
  delivered,
  cancelled,
  disputed,
  // legacy
  accepted,
  preparing,
  readyForPickup,
  completed;

  String get db {
    switch (this) {
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.dispatched:
        return 'Dispatched';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.disputed:
        return 'Disputed';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.completed:
        return 'Completed';
    }
  }

  /// Whether this status counts as a successfully fulfilled order.
  bool get isFulfilled =>
      this == OrderStatus.delivered || this == OrderStatus.completed;

  /// Whether the order is still active (not delivered/cancelled/disputed).
  bool get isActive =>
      this != OrderStatus.delivered &&
          this != OrderStatus.completed &&
          this != OrderStatus.cancelled &&
          this != OrderStatus.disputed;

  static OrderStatus fromDb(String value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'dispatched':
        return OrderStatus.dispatched;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'disputed':
        return OrderStatus.disputed;
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'completed':
        return OrderStatus.completed;
      default:
        return OrderStatus.pending;
    }
  }
}

/// How a student chooses to pay at checkout.
enum PaymentMethod {
  cashOnDelivery,
  mobileMoney;

  String get db {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
      case PaymentMethod.mobileMoney:
        return 'momo';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
    }
  }

  String get subtitle {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Pay the shop when your order arrives';
      case PaymentMethod.mobileMoney:
        return 'Secure Mobile Money payment via Paystack';
    }
  }

  /// Whether this method requires the online (Paystack Mobile Money) flow.
  bool get isOnline => this == PaymentMethod.mobileMoney;

  IconData get icon {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return Icons.payments_outlined;
      case PaymentMethod.mobileMoney:
        return Icons.phone_android_outlined;
    }
  }
}

enum UserRole { student, vendor, admin;

  static UserRole fromDb(String value) {
    switch (value) {
      case 'vendor':
        return UserRole.vendor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}

enum ApprovalStatus { pending, approved, rejected, suspended;

  static ApprovalStatus fromDb(String value) {
    switch (value) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'suspended':
        return ApprovalStatus.suspended;
      default:
        return ApprovalStatus.pending;
    }
  }

  String get label => name[0].toUpperCase() + name.substring(1);
}
