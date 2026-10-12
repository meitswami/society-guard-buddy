import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../governance/resident_documents_view.dart';

/// Legacy full-screen route — thin wrapper around [ResidentDocumentsView] (governance module).
class SocietyDocumentsScreen extends StatelessWidget {
  const SocietyDocumentsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.tr('Society documents', 'सोसायटी दस्तावेज़'))),
        body: ResidentDocumentsView(session: session),
      );
}
