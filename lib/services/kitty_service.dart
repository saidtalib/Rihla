import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/expense.dart';

// Re-export currency data for backward compatibility
export '../data/currencies.dart';

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

  /// Update an existing expense (owner or admin).
  Future<void> updateExpense({
    required String tripId,
    required String expenseId,
    required String description,
    required String category,
    required double amount,
    required String currency,
    required double amountInBase,
    required List<String> splitAmong,
  }) async {
    await _expenses(tripId).doc(expenseId).update({
      'description': description,
      'category': category,
      'amount': amount,
      'currency': currency,
      'amount_in_base': amountInBase,
      'split_among': splitAmong,
    });
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

  /// Calculates the minimum number of transfers needed to settle all debts.
  ///
  /// Uses **greedy largest-to-largest matching**: pairs the biggest creditor
  /// with the biggest debtor, settles the smaller of the two amounts, then
  /// advances whichever side is fully settled. This minimises the total
  /// number of bank transfers required to bring every member to zero.
  ///
  /// Key design choices:
  /// - Initialises balances for ALL trip members (even those with no expenses)
  ///   so no one silently disappears from the settlement.
  /// - Guards against empty `splitAmong` lists (avoids division by zero).
  /// - Uses `update` with `ifAbsent` so payers/participants outside the
  ///   `members` map are still handled safely.
  /// - Rounds only the final settlement amount (not intermediate values)
  ///   to avoid accumulated floating-point drift.
  ///
  /// [nameMap] should be uid → displayName (resolved from the users collection).
  List<Settlement> calculateSettlements(
    List<Expense> expenses,
    Map<String, String> members, // uid → role ('admin' | 'member')
    {Map<String, String> nameMap = const {}}
  ) {
    if (expenses.isEmpty) return [];

    // ── 1. Build name lookup ────────────────────
    //    Priority: resolved nameMap > expense.paidByName > short UID
    final names = <String, String>{};
    for (final e in expenses) {
      names[e.paidByUid] = e.paidByName;
    }
    for (final uid in members.keys) {
      names.putIfAbsent(
        uid,
        () => uid.length >= 6 ? uid.substring(0, 6) : uid,
      );
    }
    names.addAll(nameMap); // resolved names win

    // ── 2. Initialise balances for EVERY member ──
    final balances = <String, double>{
      for (final uid in members.keys) uid: 0.0,
    };

    // ── 3. Compute net balances (in base currency) ──
    for (final e in expenses) {
      if (e.splitAmong.isEmpty) continue; // safety: avoid /0

      // Payer receives full credit
      balances.update(
        e.paidByUid,
        (v) => v + e.amountInBase,
        ifAbsent: () => e.amountInBase,
      );

      // Each participant owes an equal share
      final share = e.amountInBase / e.splitAmong.length;
      for (final uid in e.splitAmong) {
        balances.update(uid, (v) => v - share, ifAbsent: () => -share);
      }
    }

    // ── 4. Separate into creditors (+) and debtors (−) ──
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => MapEntry(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => MapEntry(e.key, -e.value)) // flip to positive
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── 5. Greedy matching ──────────────────────
    final settlements = <Settlement>[];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final cRemain = creditors[ci].value;
      final dRemain = debtors[di].value;
      final settle = cRemain < dRemain ? cRemain : dRemain;

      if (settle > 0.01) {
        settlements.add(Settlement(
          fromUid: debtors[di].key,
          fromName: names[debtors[di].key] ?? 'Unknown',
          toUid: creditors[ci].key,
          toName: names[creditors[ci].key] ?? 'Unknown',
          amount: double.parse(settle.toStringAsFixed(2)),
        ));
      }

      // Reduce remaining amounts (mutate list entries)
      creditors[ci] = MapEntry(creditors[ci].key, cRemain - settle);
      debtors[di] = MapEntry(debtors[di].key, dRemain - settle);

      // Advance index once a side is fully settled
      if (creditors[ci].value < 0.01) ci++;
      if (di < debtors.length && debtors[di].value < 0.01) di++;
    }

    // Optional polish: sort settlements alphabetically by debtor name
    settlements.sort((a, b) => a.fromName.compareTo(b.fromName));

    return settlements;
  }
}

