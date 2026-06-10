import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../shared/widgets/biometric_enrollment_prompt.dart';
import 'admin_overview_screen.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BiometricEnrollmentPrompt(
      session: session,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin · ${session.societyName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
        body: AdminOverviewScreen(session: session),
      ),
    );
  }
}
