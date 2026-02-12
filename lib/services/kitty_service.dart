import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/expense.dart';

/// Manages expenses, currency conversion, and settlement calculations.
class KittyService {
  KittyService._();
  static final KittyService instance = KittyService._();

  final _db = FirebaseFirestore.instance;

  User? get _user => FirebaseAuth.instance.currentUser;
  String get _uid => _user?.uid ?? 'anonymous';
  String get _displayName => _user?.displayName ?? 'Traveller';

  CollectionReference<Map<String, dynamic>> _expenses(String tripId) =>
      _db.collection('trips').doc(tripId).collection('expenses');

  // ─────────────────────────────────────────────
  //  CURRENCY EXCHANGE
  // ─────────────────────────────────────────────

  /// Cache: baseCurrency -> { 'EUR': 0.85, 'USD': 1.0, ... }
  final Map<String, Map<String, double>> _rateCache = {};
  DateTime? _rateCacheTime;

  /// Fetch exchange rates from the free exchangerate.host API.
  /// Falls back to a popular free alternative if the first fails.
  Future<Map<String, double>> _fetchRates(String baseCurrency) async {
    // Use cached rates if they're less than 1 hour old
    if (_rateCache.containsKey(baseCurrency) &&
        _rateCacheTime != null &&
        DateTime.now().difference(_rateCacheTime!).inMinutes < 60) {
      return _rateCache[baseCurrency]!;
    }

    final base = baseCurrency.toUpperCase();

    // Try exchangerate-api.com (free tier)
    try {
      final url =
          'https://open.er-api.com/v6/latest/$base';
      final resp = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rates = (data['rates'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toDouble()));
          _rateCache[baseCurrency] = rates;
          _rateCacheTime = DateTime.now();
          debugPrint('[KittyService] Fetched ${rates.length} rates for $base');
          return rates;
        }
      }
    } catch (e) {
      debugPrint('[KittyService] Primary exchange API failed: $e');
    }

    // Fallback: return 1:1 if we can't reach the API
    debugPrint('[KittyService] Using fallback 1:1 rate for $base');
    return {base: 1.0};
  }

  /// Convert [amount] in [fromCurrency] to [baseCurrency].
  Future<double> convert({
    required double amount,
    required String fromCurrency,
    required String baseCurrency,
  }) async {
    if (fromCurrency.toUpperCase() == baseCurrency.toUpperCase()) {
      return amount;
    }
    final rates = await _fetchRates(baseCurrency);
    final fromRate = rates[fromCurrency.toUpperCase()];
    if (fromRate == null || fromRate == 0) {
      debugPrint(
          '[KittyService] Rate not found for $fromCurrency, returning original');
      return amount;
    }
    // rates are relative to base, so: amountInBase = amount / fromRate
    return amount / fromRate;
  }

  // ─────────────────────────────────────────────
  //  BASE CURRENCY (per trip)
  // ─────────────────────────────────────────────

  /// Get the trip's base currency (default: 'OMR').
  Future<String> getBaseCurrency(String tripId) async {
    final doc = await _db.collection('trips').doc(tripId).get();
    final data = doc.data();
    return (data?['base_currency'] as String?) ?? 'OMR';
  }

  /// Set the trip's base currency (admin only).
  Future<void> setBaseCurrency(String tripId, String currency) async {
    await _db.collection('trips').doc(tripId).update({
      'base_currency': currency.toUpperCase(),
    });
  }

  // ─────────────────────────────────────────────
  //  EXPENSE CRUD
  // ─────────────────────────────────────────────

  /// Real-time stream of all expenses for a trip.
  Stream<List<Expense>> expensesStream(String tripId) {
    return _expenses(tripId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Expense.fromFirestore(d)).toList());
  }

  /// Add a new expense.
  Future<void> addExpense({
    required String tripId,
    required String description,
    required String category,
    required double amount,
    required String currency,
    required double amountInBase,
    required List<String> splitAmong,
  }) async {
    final expense = Expense(
      id: '',
      tripId: tripId,
      paidByUid: _uid,
      paidByName: _displayName,
      description: description,
      category: category,
      amount: amount,
      currency: currency,
      amountInBase: amountInBase,
      splitAmong: splitAmong,
      createdAt: DateTime.now(),
    );
    await _expenses(tripId).add(expense.toFirestore());
  }

  /// Delete an expense (admin or the person who paid).
  Future<bool> deleteExpense(
    String tripId,
    Expense expense, {
    required bool isAdmin,
  }) async {
    if (expense.paidByUid != _uid && !isAdmin) return false;
    await _expenses(tripId).doc(expense.id).delete();
    return true;
  }

  // ─────────────────────────────────────────────
  //  SETTLEMENT ENGINE (Greedy Algorithm)
  // ─────────────────────────────────────────────

  /// Calculate optimised settlements from a list of expenses.
  ///
  /// Algorithm:
  /// 1. Compute net balance for each member:
  ///    balance = total_paid - (total_owed based on splits they're part of)
  /// 2. Sort by balance: most positive (creditors) first,
  ///    most negative (debtors) last.
  /// 3. Greedy match: biggest creditor with biggest debtor,
  ///    settle min of the two, repeat.
  List<Settlement> calculateSettlements(
    List<Expense> expenses,
    Map<String, String> members, // uid -> display name or role
  ) {
    if (expenses.isEmpty) return [];

    // Build a name lookup from members map + expenses
    final names = <String, String>{};
    for (final e in expenses) {
      names[e.paidByUid] = e.paidByName;
    }
    for (final uid in members.keys) {
      names.putIfAbsent(uid, () => 'Member ${uid.substring(0, 6)}');
    }

    // 1. Compute net balances (in base currency)
    final balances = <String, double>{};

    for (final e in expenses) {
      // The payer gets credited
      balances[e.paidByUid] =
          (balances[e.paidByUid] ?? 0.0) + e.amountInBase;

      // Each person in the split owes their share
      final share = e.amountInBase / e.splitAmong.length;
      for (final uid in e.splitAmong) {
        balances[uid] = (balances[uid] ?? 0.0) - share;
      }
    }

    // 2. Separate into creditors (+) and debtors (-)
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];

    for (final entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors.add(entry);
      } else if (entry.value < -0.01) {
        debtors.add(MapEntry(entry.key, -entry.value)); // make positive
      }
    }

    // Sort descending by amount
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    // 3. Greedy settlement
    final settlements = <Settlement>[];
    int ci = 0, di = 0;
    final cAmounts = creditors.map((e) => e.value).toList();
    final dAmounts = debtors.map((e) => e.value).toList();

    while (ci < creditors.length && di < debtors.length) {
      final settle = cAmounts[ci] < dAmounts[di] ? cAmounts[ci] : dAmounts[di];
      if (settle > 0.01) {
        settlements.add(Settlement(
          fromUid: debtors[di].key,
          fromName: names[debtors[di].key] ?? 'Unknown',
          toUid: creditors[ci].key,
          toName: names[creditors[ci].key] ?? 'Unknown',
          amount: double.parse(settle.toStringAsFixed(2)),
        ));
      }
      cAmounts[ci] -= settle;
      dAmounts[di] -= settle;
      if (cAmounts[ci] < 0.01) ci++;
      if (dAmounts[di] < 0.01) di++;
    }

    return settlements;
  }
}

/// Common world currencies for the picker.
const List<String> kCommonCurrencies = [
  'OMR', 'AED', 'SAR', 'USD', 'EUR', 'GBP', 'JPY', 'INR',
  'TRY', 'EGP', 'KWD', 'BHD', 'QAR', 'MAD', 'THB', 'MYR',
  'IDR', 'PHP', 'BRL', 'AUD', 'CAD', 'CHF', 'CNY', 'SGD',
  'ZAR', 'KES', 'NGN', 'GEL', 'AZN',
];
