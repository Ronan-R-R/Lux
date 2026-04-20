import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Auth ---
  Future<AuthResponse> signInWithEmail(String email, String password) async =>
      await _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> registerWithEmail(String email, String password) async =>
      await _client.auth.signUp(email: email, password: password);

  Future<void> signOut() async => await _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // --- Company ---
  Future<Company?> getCompany() async {
    final response = await _client.from('companies').select().maybeSingle();
    if (response == null) return null;
    return Company.fromJson(response);
  }

  Future<void> registerCompany(String name) async {
    await _client.rpc('create_company', params: {'company_name': name});
  }

  Future<void> updateCompany(String companyId, String newName) async {
    await _client.from('companies').update({'name': newName}).eq('id', companyId);
  }

  Future<void> deleteCompany(String companyId) async {
    await _client.from('companies').delete().eq('id', companyId);
  }

  // --- Company Personnel ---
  Future<List<CompanyPersonnel>> getPersonnel(String companyId) async {
    final response = await _client
        .from('company_personnel')
        .select()
        .eq('company_id', companyId)
        .order('name');
    return (response as List).map((e) => CompanyPersonnel.fromJson(e)).toList();
  }

  Future<void> addPersonnel(CompanyPersonnel person) async {
    final json = person.toJson()..remove('id');
    await _client.from('company_personnel').insert(json);
    if (person.email != null && person.email!.trim().isNotEmpty) {
      await inviteMember(person.companyId, person.email!.trim());
    }
  }

  Future<void> updatePersonnel(CompanyPersonnel person) async {
    final json = person.toJson();
    await _client.from('company_personnel').update(json).eq('id', person.id);
    if (person.email != null && person.email!.trim().isNotEmpty) {
      await inviteMember(person.companyId, person.email!.trim());
    }
  }

  Future<void> deletePersonnel(String id) async {
    await _client.from('company_personnel').delete().eq('id', id);
  }

  // --- Store Personnel ---
  Future<List<CompanyPersonnel>> getStorePersonnel(String storeId) async {
    // Join store_personnel → company_personnel
    final response = await _client
        .from('store_personnel')
        .select('personnel_id, company_personnel(id, company_id, name, code_prefix)')
        .eq('store_id', storeId);
    return (response as List)
        .map((e) => CompanyPersonnel.fromJson(e['company_personnel'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> setStorePersonnel(String storeId, List<String> personnelIds) async {
    // Clear existing, then re-insert selected
    await _client.from('store_personnel').delete().eq('store_id', storeId);
    if (personnelIds.isEmpty) return;
    final rows = personnelIds
        .map((pid) => {'store_id': storeId, 'personnel_id': pid})
        .toList();
    await _client.from('store_personnel').insert(rows);
  }

  // --- Stores ---
  Future<List<Store>> getStores() async {
    final response = await _client.from('stores').select();
    return (response as List).map((e) => Store.fromJson(e)).toList();
  }

  Future<Store> addStore(Store store) async {
    final data = store.toJson()..remove('id');
    final response =
        await _client.from('stores').insert(data).select().single();
    return Store.fromJson(response);
  }

  Future<void> updateStore(Store store) async {
    await _client.from('stores').update({
      'name': store.name,
      'commission_rate': store.commissionRate,
      'rent': store.rent,
    }).eq('id', store.id);
  }

  Future<void> deleteStore(String storeId) async {
    await _client.from('stores').delete().eq('id', storeId);
  }

  // --- General Catalogue ---
  Future<List<CatalogueItem>> getCatalogueItems(String companyId) async {
    final response = await _client
        .from('catalogue_items')
        .select()
        .eq('company_id', companyId)
        .order('item_code');
    return (response as List).map((e) => CatalogueItem.fromJson(e)).toList();
  }

  Future<void> upsertCatalogueItem(CatalogueItem item) async {
    final json = item.toJson();
    if (json['id'].isEmpty) json.remove('id');
    await _client.from('catalogue_items').upsert(
      [json],
      onConflict: 'company_id, item_code',
    );
  }

  Future<void> deleteCatalogueItem(String id) async {
    await _client.from('catalogue_items').delete().eq('id', id);
  }

  // --- Store Sales ---
  Future<List<StoreSale>> getStoreSales(String storeId) async {
    final response = await _client
        .from('store_sales')
        .select()
        .eq('store_id', storeId);
    return (response as List).map((e) => StoreSale.fromJson(e)).toList();
  }

  Future<List<SaleLineItem>> getStoreSalesMerged(
      String storeId, String companyId) async {
    final sales = await getStoreSales(storeId);
    final catalogue = await getCatalogueItems(companyId);
    final catMap = {for (var c in catalogue) c.itemCode: c};
    return sales
        .where((s) => catMap.containsKey(s.itemCode))
        .map((s) => SaleLineItem(sale: s, catalogueItem: catMap[s.itemCode]!))
        .toList();
  }

  Future<void> syncStoreSalesBulk(
      String storeId, List<Map<String, dynamic>> salesData) async {
    if (salesData.isEmpty) return;
    await _client.from('store_sales').upsert(
      salesData,
      onConflict: 'store_id, item_code',
    );
  }

  Future<void> clearStoreSales(String storeId) async {
    await _client
        .from('store_sales')
        .update({'quantity_sold': 0}).eq('store_id', storeId);
  }

  // --- Invites ---
  Future<void> inviteMember(String companyId, String email) async {
    await _client.from('company_invites').upsert({
      'company_id': companyId,
      'email': email,
      'invited_by': currentUser?.id,
    }, onConflict: 'company_id, email');
  }
}
