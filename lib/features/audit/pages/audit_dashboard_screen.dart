import 'package:flutter/material.dart';
import '../services/security_status_service.dart';
import '../widgets/audit_finding_tile.dart';

class AuditDashboardScreen extends StatefulWidget {
  const AuditDashboardScreen({super.key});

  @override
  State<AuditDashboardScreen> createState() => _AuditDashboardScreenState();
}

class _AuditDashboardScreenState extends State<AuditDashboardScreen> {
  final _service = const SecurityStatusService();
  bool? _sqlcipher;
  bool? _ci;
  bool? _semgrep;
  bool? _localScript;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _service.isSqlCipherEnabled(),
      _service.hasCiWorkflow(),
      _service.hasSemgrepRules(),
      _service.hasLocalAuditScript(),
    ]);
    if (!mounted) return;
    setState(() {
      _sqlcipher = values[0];
      _ci = values[1];
      _semgrep = values[2];
      _localScript = values[3];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _summaryCard(context),
      const SizedBox(height: 16),
      _topFindings(context),
      const SizedBox(height: 24),
      _workflows(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Audit Dashboard'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: cards,
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final ok = (_sqlcipher == true) && (_ci == true) && (_semgrep == true);
    return Material(
      color: ok
          ? Colors.green.withOpacity(0.06)
          : Colors.orange.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.verified : Icons.shield,
                  color: ok ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overall posture: ${ok ? 'Improved' : 'Medium risk'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This dashboard summarizes at-rest encryption and CI security gates. Pull to refresh.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('SQLite SQLCipher', _sqlcipher),
                _chip('CI Workflow', _ci),
                _chip('Semgrep Rules', _semgrep),
                _chip('Local Audit Script', _localScript),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool? value) {
    final v = value == true;
    return Chip(
      avatar: Icon(
        v ? Icons.check_circle : Icons.error,
        color: v ? Colors.green : Colors.orange,
        size: 18,
      ),
      label: Text(label),
      side: BorderSide(color: Colors.grey.shade300),
      backgroundColor: v
          ? Colors.green.withOpacity(0.08)
          : Colors.orange.withOpacity(0.08),
      labelStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
    );
  }

  Widget _topFindings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top findings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AuditFindingTile(
          title: 'PII stored unencrypted (Hive/SQLite)',
          severity: 'High',
          passed: _sqlcipher == true,
          description:
              'Encrypt sensitive local data. Hive user box is encrypted. SQLite is now protected by SQLCipher.',
          onTap: null,
        ),
        const SizedBox(height: 8),
        AuditFindingTile(
          title: 'Missing CI security gates',
          severity: 'Medium',
          passed: (_ci == true) && (_semgrep == true),
          description:
              'Ensure CI runs analyze, tests, OSV, semgrep, and secret scans on PRs.',
        ),
        const SizedBox(height: 8),
        AuditFindingTile(
          title: 'Incomplete secrets detection controls',
          severity: 'Medium',
          passed: _semgrep == true,
          description:
              'Adopt detect-secrets/gitleaks with a baseline and enforce in CI.',
        ),
        const SizedBox(height: 8),
        AuditFindingTile(
          title: 'Firebase rules & OAuth client restrictions',
          severity: 'Medium',
          passed: false,
          description:
              'Review and harden Firestore/Storage rules in console; restrict OAuth to packages/SHAs; enable MFA.',
        ),
      ],
    );
  }

  Widget _workflows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workflows & Docs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Audit Report'),
          subtitle: const Text('docs/audit-report.md'),
          onTap: () => _showAsset(context, 'docs/audit-report.md'),
        ),
        ListTile(
          leading: const Icon(Icons.table_view_outlined),
          title: const Text('Findings (CSV)'),
          subtitle: const Text('docs/findings.csv'),
          onTap: () => _showAsset(context, 'docs/findings.csv'),
        ),
        ListTile(
          leading: const Icon(Icons.schema_outlined),
          title: const Text('Data Flow Diagram'),
          subtitle: const Text('docs/dfd.mmd'),
          onTap: () => _showAsset(context, 'docs/dfd.mmd'),
        ),
      ],
    );
  }

  Future<void> _showAsset(BuildContext context, String assetPath) async {
    final theme = Theme.of(context);
    try {
      final text = await DefaultAssetBundle.of(context).loadString(assetPath);
      if (!mounted) return;
      // Simple reader dialog
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          backgroundColor: Colors.white,
          title: Text(assetPath, style: const TextStyle(fontSize: 14)),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open asset')));
    }
  }
}
