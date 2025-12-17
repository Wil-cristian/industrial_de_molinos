import 'package:intl/intl.dart';

class Formatters {
  // Formato de moneda
  static String currency(double amount, {String symbol = 'S/'}) {
    final formatter = NumberFormat.currency(
      locale: 'es_PE',
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Formato de número
  static String number(double value, {int decimals = 2}) {
    final formatter = NumberFormat.decimalPattern('es_PE');
    return formatter.format(value);
  }

  // Formato de fecha
  static String date(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Formato de fecha y hora
  static String dateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  // Formato de fecha larga
  static String dateLong(DateTime date) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(date);
    } catch (e) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // Formato de hora
  static String time(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  // Formato de porcentaje
  static String percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  // Formato de documento (DNI, RUC)
  static String document(String doc) {
    if (doc.length == 8) {
      // DNI
      return '${doc.substring(0, 2)}-${doc.substring(2)}';
    } else if (doc.length == 11) {
      // RUC
      return '${doc.substring(0, 2)}-${doc.substring(2, 10)}-${doc.substring(10)}';
    }
    return doc;
  }
}

class Validators {
  static String? required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  static String? dni(String? value) {
    if (value == null || value.isEmpty) {
      return 'El DNI es requerido';
    }
    if (value.length != 8 || !RegExp(r'^\d{8}$').hasMatch(value)) {
      return 'DNI debe tener 8 dígitos';
    }
    return null;
  }

  static String? ruc(String? value) {
    if (value == null || value.isEmpty) {
      return 'El RUC es requerido';
    }
    if (value.length != 11 || !RegExp(r'^\d{11}$').hasMatch(value)) {
      return 'RUC debe tener 11 dígitos';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Opcional
    }
    if (!RegExp(r'^\d{9}$').hasMatch(value)) {
      return 'Teléfono debe tener 9 dígitos';
    }
    return null;
  }

  static String? positiveNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese un valor';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Ingrese un número válido';
    }
    return null;
  }
}

/// Alias para Formatters - compatibilidad con código existente
class Helpers {
  static String formatCurrency(double amount, {String symbol = 'S/'}) =>
      Formatters.currency(amount, symbol: symbol);

  static String formatNumber(double value, {int decimals = 2}) =>
      Formatters.number(value, decimals: decimals);

  static String formatDate(DateTime date) => Formatters.date(date);

  static String formatDateTime(DateTime date) => Formatters.dateTime(date);

  static String formatDateLong(DateTime date) => Formatters.dateLong(date);

  static String formatPercentage(double value) => Formatters.percentage(value);
}
