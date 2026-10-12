import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'documents/documents_page.dart';

/// Resident "Documents" tab (web `SocietyDocumentsManager isResident viewerLabel="{flat} · {name}"`).
class ResidentDocumentsView extends StatelessWidget {
  const ResidentDocumentsView({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => DocumentsPage(
        societyId: session.societyId,
        isResident: true,
        viewerLabel: '${session.resident.flatNumber} · ${session.resident.name}',
      );
}
