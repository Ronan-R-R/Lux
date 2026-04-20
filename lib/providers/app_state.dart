import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/update_service.dart';
import '../models/models.dart';

// --- Services ---
final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());
final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());
final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService(
      repoOwner: dotenv.env['GITHUB_REPO_OWNER'] ?? '',
      repoName: dotenv.env['GITHUB_REPO_NAME'] ?? '',
    ));

// --- Auth ---
final authStateProvider = StreamProvider((ref) {
  return ref.read(supabaseServiceProvider).authStateChanges;
});

// --- Company ---
final companyProvider = FutureProvider<Company?>((ref) async {
  ref.watch(authStateProvider);
  return await ref.read(supabaseServiceProvider).getCompany();
});

// --- Company Personnel (all sellers/makers for the company) ---
final personnelProvider = FutureProvider<List<CompanyPersonnel>>((ref) async {
  final company = await ref.watch(companyProvider.future);
  if (company == null) return [];
  return await ref.read(supabaseServiceProvider).getPersonnel(company.id);
});

// --- Stores ---
final storeListProvider = FutureProvider<List<Store>>((ref) async {
  return await ref.read(supabaseServiceProvider).getStores();
});

final currentStoreProvider =
    NotifierProvider<CurrentStoreNotifier, Store?>(CurrentStoreNotifier.new);

class CurrentStoreNotifier extends Notifier<Store?> {
  @override
  Store? build() => null;
  void setStore(Store? store) => state = store;
}

// --- Store Personnel (which personnel participate in the current store) ---
final storePersonnelProvider = FutureProvider<List<CompanyPersonnel>>((ref) async {
  final store = ref.watch(currentStoreProvider);
  if (store == null) return [];
  return await ref.read(supabaseServiceProvider).getStorePersonnel(store.id);
});

// --- General Catalogue ---
final catalogueProvider = FutureProvider<List<CatalogueItem>>((ref) async {
  final company = await ref.watch(companyProvider.future);
  if (company == null) return [];
  return await ref.read(supabaseServiceProvider).getCatalogueItems(company.id);
});

// --- Store Sales (merged with catalogue for display) ---
final storeSalesProvider = FutureProvider<List<SaleLineItem>>((ref) async {
  final store = ref.watch(currentStoreProvider);
  if (store == null) return [];
  final company = await ref.watch(companyProvider.future);
  if (company == null) return [];
  return await ref
      .read(supabaseServiceProvider)
      .getStoreSalesMerged(store.id, company.id);
});
