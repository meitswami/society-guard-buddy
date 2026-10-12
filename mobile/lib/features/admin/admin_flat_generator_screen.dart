import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'people/residents/flat_generator_page.dart';

/// Legacy entry point — bulk flat generation from the society layout.
class AdminFlatGeneratorScreen extends StatelessWidget {
  const AdminFlatGeneratorScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  Widget build(BuildContext context) =>
      FlatGeneratorPage(societyId: session.societyId, adminId: session.admin.id, adminName: session.admin.name);
}
