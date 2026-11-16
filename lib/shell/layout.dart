import 'package:flutter/material.dart';

/// Lebar jendela mulai dari sini memakai tata letak desktop (sidebar, kolom isi di tengah).
const kWideBreakpoint = 900.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Jarak kiri-kanan supaya isi selebar [maxWidth] berada di tengah ruang [viewport] (minimal [min]).
double sideGutter(double viewport, double maxWidth, {double min = 20}) {
  final g = (viewport - maxWidth) / 2;
  return g < min ? min : g;
}
