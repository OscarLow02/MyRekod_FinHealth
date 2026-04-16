import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_profile.dart';
import '../models/sale_item.dart';
import '../models/tax_config.dart';

/// Thin wrapper around Cloud Firestore for all app CRUD operations.
///
/// Firestore schema:
/// ```
/// business_profiles/
///   {userId}/                          ← BusinessProfile document
///     sale_items/
///       {itemId}/                      ← SaleItem document
///     settings/
///       tax_config/                    ← TaxConfig document
/// ```
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection helpers ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _profilesCol() =>
      _db.collection('business_profiles');

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _profilesCol().doc(uid);

  CollectionReference<Map<String, dynamic>> _itemsCol(String uid) =>
      _profileDoc(uid).collection('sale_items');

  DocumentReference<Map<String, dynamic>> _taxConfigDoc(String uid) =>
      _profileDoc(uid).collection('settings').doc('tax_config');

  // ── Business Profile ────────────────────────────────────────────────────

  /// Saves (upserts) a [BusinessProfile] to Firestore using the user's UID
  /// as the document ID for easy lookup. Uses [merge: true] so partial
  /// updates don't clobber existing fields.
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    await _profileDoc(profile.userId).set(
      profile.toFirestore(),
      SetOptions(merge: true),
    );
  }

  /// Retrieves a [BusinessProfile] by user ID.
  /// Returns null if no profile exists for this user.
  Future<BusinessProfile?> getBusinessProfile(String userId) async {
    final doc = await _profileDoc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BusinessProfile.fromFirestore(doc);
  }

  /// Checks whether a business profile exists for the given user.
  Future<bool> hasBusinessProfile(String userId) async {
    final doc = await _profileDoc(userId).get();
    return doc.exists;
  }

  // ── Sale Items ──────────────────────────────────────────────────────────

  /// Returns a real-time stream of all sale items for a user.
  /// Ordered by creation date, newest last.
  Stream<List<SaleItem>> watchSaleItems(String userId) {
    return _itemsCol(userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(SaleItem.fromFirestore).toList());
  }

  /// Adds a new sale item to Firestore. Firestore auto-generates the doc ID.
  Future<SaleItem> addSaleItem(String userId, SaleItem item) async {
    final ref = await _itemsCol(userId).add(item.toFirestore());
    final doc = await ref.get();
    return SaleItem.fromFirestore(doc);
  }

  /// Updates an existing sale item.
  Future<void> updateSaleItem(String userId, SaleItem item) async {
    await _itemsCol(userId).doc(item.id).update(item.toFirestore());
  }

  /// Deletes a sale item by its document ID.
  Future<void> deleteSaleItem(String userId, String itemId) async {
    await _itemsCol(userId).doc(itemId).delete();
  }

  // ── Tax Config ──────────────────────────────────────────────────────────

  /// Saves (upserts) the tax configuration for a user.
  Future<void> saveTaxConfig(String userId, TaxConfig config) async {
    await _taxConfigDoc(userId).set(
      config.toFirestore(),
      SetOptions(merge: true),
    );
  }

  /// Retrieves the tax configuration for a user.
  /// Returns [TaxConfig.empty] if none has been saved.
  Future<TaxConfig> getTaxConfig(String userId) async {
    final doc = await _taxConfigDoc(userId).get();
    if (!doc.exists || doc.data() == null) return TaxConfig.empty;
    return TaxConfig.fromFirestore(doc);
  }

  // ── Deactivate User Account ──────────────────────────────────────────────────────────
  /// Fully deletes a user's existence from the database.
  /// This deletes the main profile document. Note: Subcollections might persist
  Future<void> deleteFullProfile(String userId) async {
    // Delete items subcollection first (optional but cleaner)
    final items = await _itemsCol(userId).get();
    for (var doc in items.docs) {
      await doc.reference.delete();
    }
    
    // Delete settings
    await _taxConfigDoc(userId).delete();

    // Delete main profile
    await _profileDoc(userId).delete();
  }
}
