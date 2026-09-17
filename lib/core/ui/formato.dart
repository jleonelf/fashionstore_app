import 'package:intl/intl.dart';

final _moneda =
    NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);
final _fecha = DateFormat('dd/MM/yyyy HH:mm', 'es');
final _fechaCorta = DateFormat('dd/MM/yyyy', 'es');

String formatoPrecio(double v) => _moneda.format(v);

String formatoFecha(DateTime? f) {
  if (f == null) return '—';
  return _fecha.format(f.toLocal());
}

String formatoFechaCorta(DateTime? f) {
  if (f == null) return '—';
  return _fechaCorta.format(f.toLocal());
}

/// Texto de vigencia: "Vence el ..." + si ya venció.
String textoVigencia(DateTime? venceEn, {DateTime? ahora}) {
  if (venceEn == null) return 'Sin fecha de vencimiento registrada.';
  final ref = ahora ?? DateTime.now();
  final local = venceEn.toLocal();
  if (ref.isAfter(local)) {
    return 'Venció el ${formatoFecha(local)}.';
  }
  final diff = local.difference(ref);
  if (diff.inHours < 24) {
    return 'Vence el ${formatoFecha(local)} (en ${diff.inHours} h aprox.).';
  }
  return 'Vence el ${formatoFecha(local)} (en ${diff.inDays} día(s) aprox.).';
}
