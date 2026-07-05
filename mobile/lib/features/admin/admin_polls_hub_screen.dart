import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import 'admin_elections_screen.dart';
import 'admin_standard_polls_tab.dart';

/// Polls & elections hub — matches web PollManager section tabs.
class AdminPollsHubScreen extends StatefulWidget {
  const AdminPollsHubScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminPollsHubScreen> createState() => _AdminPollsHubScreenState();
}

class _AdminPollsHubScreenState extends State<AdminPollsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _electionsKey = GlobalKey<AdminElectionsScreenState>();
  final _standardPollsKey = GlobalKey<AdminStandardPollsTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onFab() {
    if (_tabs.index == 0) {
      _electionsKey.currentState?.createElection();
    } else {
      _standardPollsKey.currentState?.createPoll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Polls & elections'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: brand.primary,
          tabs: const [
            Tab(text: 'Society elections'),
            Tab(text: 'General polls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          AdminElectionsScreen(
            key: _electionsKey,
            session: widget.session,
            embedded: true,
          ),
          AdminStandardPollsTab(key: _standardPollsKey, session: widget.session),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          return FloatingActionButton.extended(
            onPressed: _onFab,
            icon: const Icon(Icons.add),
            label: Text(_tabs.index == 0 ? 'Election' : 'Poll'),
          );
        },
      ),
    );
  }
}
