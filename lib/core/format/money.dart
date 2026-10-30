import 'package:intl/intl.dart';

final _etb = NumberFormat('#,##0', 'en_US');

/// Whole ETB amounts with a thousands separator: 1,250.
String etb(num amount) => _etb.format(amount);
