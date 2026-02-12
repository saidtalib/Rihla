import 'package:cloud_firestore/cloud_firestore.dart';

/// A single expense entry in a trip's kitty.
class Expense {
  final String id;
  final String tripId;
  final String paidByUid;
  final String paidByName;
  final String description;
  final String category;
  final double amount; // original amount in [currency]
  final String currency; // e.g. 'EUR', 'OMR', 'USD'
  final double amountInBase; // converted to the trip's base currency
  final List<String> splitAmong; // UIDs that share this expense
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.tripId,
    required this.paidByUid,
    required this.paidByName,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.amountInBase,
    required this.splitAmong,
    required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      tripId: d['trip_id'] as String? ?? '',
      paidByUid: d['paid_by_uid'] as String? ?? '',
      paidByName: d['paid_by_name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'Other',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      currency: d['currency'] as String? ?? 'USD',
      amountInBase: (d['amount_in_base'] as num?)?.toDouble() ?? 0.0,
      splitAmong: List<String>.from(d['split_among'] ?? []),
      createdAt:
          (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'trip_id': tripId,
        'paid_by_uid': paidByUid,
        'paid_by_name': paidByName,
        'description': description,
        'category': category,
        'amount': amount,
        'currency': currency,
        'amount_in_base': amountInBase,
        'split_among': splitAmong,
        'created_at': Timestamp.fromDate(createdAt),
      };
}

/// A settlement action: one person pays another.
class Settlement {
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final double amount; // in base currency

  const Settlement({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.amount,
  });
}

/// Default expense categories with emoji icons.
class ExpenseCategory {
  final String key;
  final String labelEn;
  final String labelAr;
  final String emoji;
  final List<String> keywords; // for smart autocomplete

  const ExpenseCategory({
    required this.key,
    required this.labelEn,
    required this.labelAr,
    required this.emoji,
    this.keywords = const [],
  });
}

const List<ExpenseCategory> kExpenseCategories = [
  ExpenseCategory(
    key: 'car_rental',
    labelEn: 'Car Rental',
    labelAr: 'تأجير سيارة',
    emoji: '🚗',
    keywords: ['car', 'rental', 'vehicle', 'suv', 'jeep', 'rent'],
  ),
  ExpenseCategory(
    key: 'restaurant',
    labelEn: 'Restaurant',
    labelAr: 'مطعم',
    emoji: '🍽️',
    keywords: [
      'food', 'restaurant', 'dinner', 'lunch', 'breakfast', 'steak',
      'pizza', 'burger', 'meal', 'cafe', 'coffee', 'eat',
    ],
  ),
  ExpenseCategory(
    key: 'tickets',
    labelEn: 'Tickets',
    labelAr: 'تذاكر',
    emoji: '🎫',
    keywords: [
      'ticket', 'entry', 'admission', 'museum', 'show', 'concert',
      'movie', 'park', 'attraction', 'tour',
    ],
  ),
  ExpenseCategory(
    key: 'fuel',
    labelEn: 'Fuel',
    labelAr: 'وقود',
    emoji: '⛽',
    keywords: ['fuel', 'gas', 'petrol', 'diesel', 'station', 'fill'],
  ),
  ExpenseCategory(
    key: 'groceries',
    labelEn: 'Groceries',
    labelAr: 'مقاضي',
    emoji: '🛒',
    keywords: [
      'grocery', 'groceries', 'supermarket', 'market', 'snack',
      'water', 'drink', 'supplies',
    ],
  ),
  ExpenseCategory(
    key: 'shopping',
    labelEn: 'Shopping',
    labelAr: 'تسوق',
    emoji: '🛍️',
    keywords: [
      'shopping', 'souvenir', 'gift', 'clothes', 'mall', 'store',
    ],
  ),
  ExpenseCategory(
    key: 'accommodation',
    labelEn: 'Accommodation',
    labelAr: 'سكن',
    emoji: '🏨',
    keywords: [
      'hotel', 'hostel', 'airbnb', 'accommodation', 'stay', 'camp',
      'lodge', 'room', 'booking',
    ],
  ),
  ExpenseCategory(
    key: 'transport',
    labelEn: 'Transport',
    labelAr: 'مواصلات',
    emoji: '🚕',
    keywords: [
      'taxi', 'uber', 'bus', 'train', 'flight', 'transport', 'ferry',
      'transfer', 'ride',
    ],
  ),
  ExpenseCategory(
    key: 'other',
    labelEn: 'Other',
    labelAr: 'أخرى',
    emoji: '📦',
    keywords: [],
  ),
];

/// Given a description, suggest the best matching category key.
String suggestCategory(String description) {
  final lower = description.toLowerCase();
  int bestScore = 0;
  String bestKey = 'other';

  for (final cat in kExpenseCategories) {
    int score = 0;
    for (final kw in cat.keywords) {
      if (lower.contains(kw)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      bestKey = cat.key;
    }
  }
  return bestKey;
}

ExpenseCategory categoryByKey(String key) {
  return kExpenseCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => kExpenseCategories.last,
  );
}
