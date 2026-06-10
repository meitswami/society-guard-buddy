import 'package:flutter/material.dart';

Color parseHexColor(String? hex, {required Color fallback}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}
