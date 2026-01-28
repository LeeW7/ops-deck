import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../providers/issue_board_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      settings.loadSettings().then((_) {
        if (mounted) {
          _urlController.text = settings.baseUrl;
        }
      });
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: const Color(0xFF00FF41),
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('SERVER CONFIGURATION'),
                  const SizedBox(height: 16),
                  _buildUrlField(settings),
                  const SizedBox(height: 24),
                  _buildConnectionStatus(settings),
                  const SizedBox(height: 24),
                  _buildActionButtons(settings),
                  const SizedBox(height: 40),
                  _buildInfoSection(),
                  const SizedBox(height: 40),
                  _buildAboutSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          color: const Color(0xFF00FF41),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FF41),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUrlField(SettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF30363D),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _urlController,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          color: Color(0xFFE6EDF3),
        ),
        decoration: InputDecoration(
          labelText: 'Server Base URL',
          labelStyle: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF8B949E),
          ),
          hintText: 'http://localhost:5001',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            color: const Color(0xFF8B949E).withOpacity(0.5),
          ),
          prefixIcon: const Icon(
            Icons.dns_outlined,
            color: Color(0xFF00FF41),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        keyboardType: TextInputType.url,
        onChanged: (_) => settings.clearTestResult(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a server URL';
          }
          if (!value.startsWith('http://') && !value.startsWith('https://')) {
            return 'URL must start with http:// or https://';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildConnectionStatus(SettingsProvider settings) {
    if (settings.isTesting) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Testing connection...',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      );
    }

    if (settings.connectionSuccess != null) {
      final isSuccess = settings.connectionSuccess!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSuccess ? const Color(0xFF238636) : const Color(0xFFDA3633),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? const Color(0xFF3FB950) : const Color(0xFFF85149),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess
                    ? 'Connection successful!'
                    : settings.testError ?? 'Connection failed',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isSuccess ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionButtons(SettingsProvider settings) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: settings.isTesting
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      await settings.testConnection(_urlController.text);
                    }
                  },
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('TEST'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00FF41),
              side: const BorderSide(color: Color(0xFF00FF41)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: settings.isTesting
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      await settings.saveBaseUrl(_urlController.text);
                      await context.read<JobProvider>().checkConfiguration();
                      await context.read<IssueBoardProvider>().initialize();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Settings saved',
                              style: TextStyle(fontFamily: 'monospace'),
                            ),
                            backgroundColor: const Color(0xFF238636),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    }
                  },
            icon: const Icon(Icons.save),
            label: const Text('SAVE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF8B949E),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'INFO',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B949E),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Expected endpoint:', '/api/status'),
          _buildInfoRow('Polling interval:', '2 seconds'),
          _buildInfoRow('Log endpoint:', '/api/logs/<id>'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF00FF41),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ABOUT'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'App Version',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFF8B949E),
                ),
              ),
              Text(
                _packageInfo != null
                    ? '${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                    : '...',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
