import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class CompanyOnboardingScreen extends ConsumerStatefulWidget {
  const CompanyOnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState
    extends ConsumerState<CompanyOnboardingScreen> {
  final _companyNameCtrl = TextEditingController();
  final List<_PersonnelEntry> _personnel = [];
  bool _isLoading = false;
  int _step = 0; // 0 = company name, 1 = add personnel

  void _nextStep() {
    if (_companyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company name.')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  void _addPersonnelRow() {
    setState(() => _personnel.add(_PersonnelEntry()));
  }

  void _removePersonnelRow(int index) {
    setState(() => _personnel.removeAt(index));
  }

  Future<void> _finish() async {
    if (_personnel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one person before continuing.')),
      );
      return;
    }

    // Validate all rows
    for (var p in _personnel) {
      if (p.nameCtrl.text.trim().isEmpty || p.prefixCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill in name and code prefix for each person.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);

      // 1. Create company
      await service.registerCompany(_companyNameCtrl.text.trim());
      ref.invalidate(companyProvider);

      // 2. Fetch the newly created company to get its ID
      final company = await ref.read(companyProvider.future);
      if (company == null) throw Exception('Company creation failed.');

      // 3. Add each personnel entry
      for (var p in _personnel) {
        await service.addPersonnel(CompanyPersonnel(
          id: '',
          companyId: company.id,
          name: p.nameCtrl.text.trim(),
          codePrefix: p.prefixCtrl.text.trim().toUpperCase(),
          email: p.emailCtrl.text.trim().isEmpty ? null : p.emailCtrl.text.trim(),
        ));
      }
      ref.invalidate(personnelProvider);

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Setup'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(supabaseServiceProvider).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _step == 0 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 1 of 2',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Text('Name your company',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'This is the name that identifies your business within Lux.'),
        const SizedBox(height: 32),
        TextField(
          controller: _companyNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            hintText: 'e.g. Acme Corp',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mintGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _nextStep,
          child: const Text('Next: Add People',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText)),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 2 of 2',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Text('Add your people',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Add everyone who sells items. Each person gets a unique code prefix '
          '(e.g. TSTA for Alice, TSTB for Bob). This prefix must match their item codes in the PDF.',
        ),
        const SizedBox(height: 24),

        // Personnel rows
        Expanded(
          child: ListView.builder(
            itemCount: _personnel.length,
            itemBuilder: (ctx, i) {
              final p = _personnel[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.babyBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: p.nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    hintText: 'e.g. Alice',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: p.prefixCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Prefix',
                                    hintText: 'e.g. TSTA',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 8,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                                      null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: p.emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email (Optional)',
                              hintText: 'If provided, they can log in',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () => _removePersonnelRow(i),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Person'),
          onPressed: _addPersonnelRow,
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.palePink,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _finish,
            child: const Text('Create Company',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText)),
          ),
      ],
    );
  }
}

class _PersonnelEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController prefixCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
}
