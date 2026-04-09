import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_profile.dart';

/// Thin wrapper around Cloud Firestore for BusinessProfile CRUD.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'business_profiles';

  /// Saves a [BusinessProfile] to Firestore using the user's UID
  /// as the document ID for easy lookup.
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    await _db
        .collection(_collection)
        .doc(profile.userId)
        .set(profile.toFirestore());
  }

  /// Retrieves a [BusinessProfile] by user ID.
  /// Returns null if no profile exists for this user.
  Future<BusinessProfile?> getBusinessProfile(String userId) async {
    final doc = await _db.collection(_collection).doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BusinessProfile.fromFirestore(doc);
  }

  /// Checks whether a business profile exists for the given user.
  Future<bool> hasBusinessProfile(String userId) async {
    final doc = await _db.collection(_collection).doc(userId).get();
    return doc.exists;
  }
}
