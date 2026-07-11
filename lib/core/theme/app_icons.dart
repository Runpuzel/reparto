import 'package:flutter/material.dart';

/// Centralised icon set.
///
/// Every screen references icons through here so the icon family stays
/// consistent and any swap happens in one place.
///
/// Implementation note: we use Flutter's built-in **Material** icons (rounded
/// where available). The `phosphor_flutter` package was dropped because its
/// 2.1.0 release extends `IconData`, which is a `final` class in Dart 3.x and
/// therefore fails to compile. Material icons need no extra dependency and are
/// guaranteed to build. To switch to Phosphor later, only this file changes.
class AppIcons {
  AppIcons._();

  // Account and identity
  static const IconData email = Icons.mail_outline_rounded;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData lockReset = Icons.lock_reset_rounded;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData signIn = Icons.login_rounded;
  static const IconData signOut = Icons.logout_rounded;
  static const IconData user = Icons.person_outline_rounded;
  static const IconData badge = Icons.badge_outlined;
  static const IconData shield = Icons.verified_user_outlined;

  // Places and contact
  static const IconData campus = Icons.apartment_rounded;
  static const IconData mapPin = Icons.location_on_outlined;
  static const IconData phone = Icons.phone_outlined;
  static const IconData phoneBusiness = Icons.call_outlined;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData whatsapp = Icons.message_rounded;
  static const IconData chat = Icons.chat_bubble_outline_rounded;

  // Shopping and orders
  static const IconData storefront = Icons.storefront_outlined;
  static const IconData storefrontFill = Icons.storefront;
  static const IconData student = Icons.school_outlined;
  static const IconData cart = Icons.shopping_cart_outlined;
  static const IconData cartFill = Icons.shopping_cart;
  static const IconData addToCart = Icons.add_shopping_cart_rounded;
  static const IconData bag = Icons.shopping_bag_outlined;
  static const IconData receipt = Icons.receipt_long_outlined;
  static const IconData receiptFill = Icons.receipt_long;
  static const IconData package = Icons.inventory_2_outlined;
  static const IconData truck = Icons.local_shipping_outlined;
  static const IconData flash = Icons.bolt_rounded;
  static const IconData grid = Icons.grid_view_outlined;
  static const IconData gridFill = Icons.grid_view_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData tag = Icons.sell_outlined;

  // Browse, search, and actions
  static const IconData search = Icons.search_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData heart = Icons.favorite_border_rounded;
  static const IconData heartFill = Icons.favorite_rounded;
  static const IconData star = Icons.star_border_rounded;
  static const IconData starFill = Icons.star_rounded;
  static const IconData images = Icons.collections_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData notification = Icons.notifications_outlined;
  static const IconData account = Icons.account_circle_outlined;
  static const IconData cod = Icons.payments_outlined;
  static const IconData note = Icons.sticky_note_2_outlined;
  static const IconData download = Icons.download_rounded;
  static const IconData trash = Icons.delete_outline_rounded;
  static const IconData sweep = Icons.delete_sweep_outlined;
  static const IconData minus = Icons.remove_rounded;
  static const IconData plus = Icons.add_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData cancel = Icons.cancel_outlined;
  static const IconData cancelFill = Icons.cancel_rounded;
  static const IconData role = Icons.badge_outlined;

  // Feedback and navigation
  static const IconData info = Icons.info_outline_rounded;
  static const IconData check = Icons.check_circle_outline_rounded;
  static const IconData checkFill = Icons.check_circle_rounded;
  static const IconData arrowRight = Icons.arrow_forward_rounded;
  static const IconData caretRight = Icons.chevron_right_rounded;
  static const IconData circle = Icons.radio_button_unchecked_rounded;
  static const IconData openInNew = Icons.open_in_new_rounded;

  // Dashboards and management
  static const IconData dashboard = Icons.dashboard_outlined;
  static const IconData dashboardFill = Icons.dashboard_rounded;
  static const IconData packageFill = Icons.inventory_2_rounded;
  static const IconData reports = Icons.bar_chart_rounded;
  static const IconData reportsFill = Icons.bar_chart_rounded;
  static const IconData person = Icons.person_outline_rounded;
  static const IconData personFill = Icons.person_rounded;
  static const IconData insights = Icons.insights_rounded;
  static const IconData leaderboard = Icons.leaderboard_outlined;
  static const IconData reviews = Icons.reviews_outlined;
  static const IconData label = Icons.label_outline_rounded;
  static const IconData category = Icons.category_outlined;
  static const IconData price = Icons.attach_money_rounded;
  static const IconData numbers = Icons.numbers_rounded;
  static const IconData save = Icons.save_outlined;
  static const IconData addBox = Icons.add_box_outlined;
  static const IconData add = Icons.add_rounded;
  static const IconData call = Icons.call_rounded;
  static const IconData sms = Icons.sms_outlined;
  static const IconData copy = Icons.copy_rounded;
  static const IconData map = Icons.map_outlined;
  static const IconData pending = Icons.hourglass_top_rounded;
  static const IconData block = Icons.block_rounded;
  static const IconData store = Icons.store_mall_directory_outlined;
  static const IconData revenue = Icons.payments_outlined;
  static const IconData edit = Icons.edit_outlined;

  // Additional icons centralised from inline usage
  static const IconData share = Icons.share_outlined;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData designServices = Icons.design_services_outlined;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOffIcon = Icons.visibility_off_rounded;
  static const IconData timerAlert = Icons.timer_outlined;
  static const IconData eventAvailable = Icons.event_available_outlined;
  static const IconData cardMembership = Icons.card_membership_outlined;
  static const IconData searchOff = Icons.search_off_rounded;
  static const IconData analytics = Icons.analytics_outlined;
  static const IconData brokenImage = Icons.broken_image_rounded;
  static const IconData errorOutline = Icons.error_outline_rounded;

  // Services and service categories
  static const IconData services = Icons.handyman_outlined;
  static const IconData servicesFill = Icons.handyman_rounded;
  static const IconData clock = Icons.schedule_rounded;
  static const IconData scissors = Icons.content_cut_rounded;
  static const IconData beauty = Icons.face_retouching_natural_outlined;
  static const IconData repair = Icons.build_outlined;
  static const IconData academic = Icons.menu_book_outlined;
  static const IconData printing = Icons.print_outlined;
  static const IconData creative = Icons.brush_outlined;
  static const IconData laundry = Icons.local_laundry_service_outlined;
  static const IconData delivery = Icons.delivery_dining_outlined;
  static const IconData transport = Icons.directions_car_outlined;
  static const IconData cleaning = Icons.cleaning_services_outlined;
  static const IconData events = Icons.celebration_outlined;
  static const IconData food = Icons.restaurant_outlined;
  static const IconData fitness = Icons.fitness_center_outlined;
  static const IconData homeServices = Icons.home_repair_service_outlined;

  static IconData serviceCategory(String category) {
    switch (category) {
      case 'hair_grooming':
        return scissors;
      case 'beauty_makeup':
        return beauty;
      case 'technical_repairs':
        return repair;
      case 'academic_support':
        return academic;
      case 'printing_typing':
        return printing;
      case 'creative_services':
        return creative;
      case 'laundry_cleaning':
        return laundry;
      case 'delivery_errands':
        return delivery;
      case 'transport_errands':
        return transport;
      case 'room_cleaning':
        return cleaning;
      case 'event_support':
        return events;
      case 'food_catering':
        return food;
      case 'fitness_sports':
        return fitness;
      case 'home_room_services':
        return homeServices;
      default:
        return services;
    }
  }

  // Admin
  static const IconData verified = Icons.verified_user_outlined;
  static const IconData verifiedFill = Icons.verified_user_rounded;
  static const IconData categoryFill = Icons.category_rounded;
  static const IconData campusFill = Icons.apartment_rounded;
  static const IconData users = Icons.group_outlined;
  static const IconData usersFill = Icons.group_rounded;
  static const IconData insightsOutline = Icons.insights_outlined;
  static const IconData people = Icons.people_alt_outlined;
  static const IconData approved = Icons.verified_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData imageSearch = Icons.image_search_rounded;
  static const IconData business = Icons.business_outlined;
  static const IconData bellActive = Icons.notifications_active_rounded;
  static const IconData bellOff = Icons.notifications_off_outlined;
  static const IconData bellNone = Icons.notifications_none_rounded;
}
