import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeShopifyVariant {
  final String productId;
  final String variantId;
  final int quantity;

  ChallengeShopifyVariant({
    required this.productId,
    required this.variantId,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      'quantity': quantity,
    };
  }

  factory ChallengeShopifyVariant.fromMap(Map<String, dynamic> map) {
    return ChallengeShopifyVariant(
      productId: map['productId'] ?? '',
      variantId: map['variantId'] ?? '',
      quantity: map['quantity'] ?? 1,
    );
  }
}

class ChallengePackage {
  final String id;
  final String challengeId;
  final String name;
  final String description;
  final double packagePrice;
  final String currency;
  final int displayOrder;
  final bool isActive;
  final bool challengeEntryIncluded;
  final List<ChallengeShopifyVariant> shopifyVariants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChallengePackage({
    required this.id,
    required this.challengeId,
    required this.name,
    required this.description,
    required this.packagePrice,
    this.currency = 'USD',
    this.displayOrder = 0,
    this.isActive = true,
    this.challengeEntryIncluded = true,
    this.shopifyVariants = const [],
    this.createdAt,
    this.updatedAt,
  });

  ChallengePackage copyWith({
    String? id,
    String? challengeId,
    String? name,
    String? description,
    double? packagePrice,
    String? currency,
    int? displayOrder,
    bool? isActive,
    bool? challengeEntryIncluded,
    List<ChallengeShopifyVariant>? shopifyVariants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChallengePackage(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      name: name ?? this.name,
      description: description ?? this.description,
      packagePrice: packagePrice ?? this.packagePrice,
      currency: currency ?? this.currency,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      challengeEntryIncluded: challengeEntryIncluded ?? this.challengeEntryIncluded,
      shopifyVariants: shopifyVariants ?? this.shopifyVariants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'name': name,
      'description': description,
      'packagePrice': packagePrice,
      'currency': currency,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'challengeEntryIncluded': challengeEntryIncluded,
      'shopifyVariants': shopifyVariants.map((v) => v.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ChallengePackage.fromMap(Map<String, dynamic> map, String documentId) {
    return ChallengePackage(
      id: documentId,
      challengeId: map['challengeId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      packagePrice: (map['packagePrice'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      displayOrder: map['displayOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      challengeEntryIncluded: map['challengeEntryIncluded'] ?? true,
      shopifyVariants: (map['shopifyVariants'] as List? ?? [])
          .map((v) => ChallengeShopifyVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ChallengePackage.fromFirestore(DocumentSnapshot doc) {
    return ChallengePackage.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
