import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  void _showPersonnelDialog({CompanyPersonnel? person}) async {
    final company = await ref.read(companyProvider.future);
    if (company == null || !mounted) return;

    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final prefixCtrl = TextEditingController(text: person?.codePrefix ?? '');
    final emailCtrl = TextEditingController(text: person?.email ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(person == null ? 'Add Personnel' : 'Edit Personnel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Alice',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prefixCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code Prefix',
                  hintText: 'e.g. TSTA',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  hintText: 'Required if they need to log in',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintGreen),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final prefix = prefixCtrl.text.trim().toUpperCase();
              final email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();

              if (name.isEmpty || prefix.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Name and Code Prefix are required.')),
                );
                return;
              }

              final newPerson = CompanyPersonnel(
                id: person?.id ?? '',
                companyId: company.id,
                name: name,
                codePrefix: prefix,
                email: email,
              );

              try {
                if (person == null) {
                  await ref.read(supabaseServiceProvider).addPersonnel(newPerson);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Personnel added (Invite sent to email if provided)')),
                    );
                  }
                } else {
                  await ref.read(supabaseServiceProvider).updatePersonnel(newPerson);
                }
                ref.invalidate(personnelProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.darkText)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CompanyPersonnel person) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Personnel'),
        content: Text(
          'Are you sure you want to remove ${person.name} (${person.codePrefix})?\n\n'
          'This will remove them from all active stores but will NOT delete their past sales records.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).deletePersonnel(person.id);
        ref.invalidate(personnelProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showEditCompanyDialog(Company company) async {
    final nameCtrl = TextEditingController(text: company.name);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Company Name'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintGreen),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              try {
                await ref.read(supabaseServiceProvider).updateCompany(company.id, newName);
                ref.invalidate(companyProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.darkText)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCompany(Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Company'),
        content: const Text(
          'DANGER: Are you absolutely sure you want to delete this company?\n\n'
          'This will permanently erase ALL stores, personnel, inventory, and sales data! '
          'This action cannot be undone.',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE FOREVER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).deleteCompany(company.id);
        ref.invalidate(companyProvider);
        // Let the router redirect back to onboarding
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting company: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);
    final personnelAsync = ref.watch(personnelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
      ),
      body: companyAsync.when(
        data: (company) {
          if (company == null) return const Center(child: Text('No company found.'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Company Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: AppTheme.babyBlue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.babyBlue.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Company Name', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    subtitle: Text(company.name, style: const TextStyle(fontSize: 18, color: Colors.black87)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditCompanyDialog(company),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Personnel & Members',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      onPressed: () => _showItemDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                personnelAsync.when(
                  data: (personnel) {
                    if (personnel.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No personnel added yet.'),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: personnel.length,
                      itemBuilder: (ctx, i) {
                        final p = personnel[i];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Prefix: ${p.codePrefix} ${p.email != null ? '\nEmail: ${p.email}' : ''}'),
                            isThreeLine: p.email != null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showPersonnelDialog(person: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, trace) => Text('Error: $e'),
                ),
                
                const SizedBox(height: 60),
                Divider(color: Colors.redAccent.withOpacity(0.3)),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmDeleteCompany(company),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    label: const Text('Delete Company', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, trace) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showItemDialog({CompanyPersonnel? person}) {
    _showPersonnelDialog(person: person);
  }
}
