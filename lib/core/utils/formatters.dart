import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class Formatters {
  static final _money = NumberFormat('#,##0.00');
  static final _date = DateFormat('d MMM, h:mm a');

  static String money(num value) =>
      '${AppConstants.currencySymbol}${_money.format(value)}';

  static String dateTime(DateTime dt) => _date.format(dt);
}
