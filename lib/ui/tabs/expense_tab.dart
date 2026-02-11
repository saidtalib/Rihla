import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';

/// A single expense entry.
class _Expense {
  final String id;
  final String description;
  final double amount;
  final String paidBy;       // uid
  final String paidByName;
  final List<String> splitWith; // uids
  final DateTime date;

  _Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.splitWith,
    required this.date,
  });

  factory _Expense.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return _Expense(
      id: doc.id,
      description: d['description'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paidBy: d['paid_by'] ?? '',
      paidByName: d['paid_by_name'] ?? 'Someone',
      splitWith: List<String>.from(d['split_with'] ?? []),
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Tab 3: Kittysplit-style expense manager for the trip.
class ExpenseTab extends StatefulWidget {
  const ExpenseTab({super.key, required this.trip});
  final Trip trip;

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  CollectionReference<Map<String, dynamic>> get _expenses =>
      FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.trip.id)
          .collection('expenses');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  String get _name =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Traveller';

  void _addExpense() {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? RihlaColors.darkCard : RihlaColors.saharaSand,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                ar ? 'إضافة مصروف' : 'Add Expense',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: descCtrl,
                keyboardType: TextInputType.text,
                style: TextStyle(
                    color: dark
                        ? RihlaColors.darkText
                        : RihlaColors.jungleGreenDark),
                decoration: InputDecoration(
                  hintText: ar ? 'مثال: عشاء، تاكسي...' : 'e.g. Dinner, Taxi...',
                  prefixIcon: Icon(Icons.receipt_long_rounded,
                      color: RihlaColors.sunsetOrange),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: dark
                        ? RihlaColors.darkText
                        : RihlaColors.jungleGreenDark),
                decoration: InputDecoration(
                  hintText: ar ? 'المبلغ' : 'Amount',
                  prefixIcon: Icon(Icons.attach_money_rounded,
                      color: RihlaColors.sunsetOrange),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final desc = descCtrl.text.trim();
                  final amt =
                      double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (desc.isEmpty || amt <= 0) return;

                  await _expenses.add({
                    'description': desc,
                    'amount': amt,
                    'paid_by': _uid,
                    'paid_by_name': _name,
                    'split_with': widget.trip.paidMembers,
                    'date': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(ar ? 'إضافة' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;
    final headingColor =
        dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            _expenses.orderBy('date', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: RihlaColors.jungleGreen));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on_rounded,
                      size: 64,
                      color: RihlaColors.sunsetOrange.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    ar ? 'لا توجد مصاريف بعد' : 'No expenses yet',
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 18,
                        color: headingColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ar
                        ? 'اضغط + لإضافة مصروف'
                        : 'Tap + to add an expense',
                    style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        color: headingColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }

          final expenses =
              docs.map((d) => _Expense.fromFirestore(d)).toList();
          final total =
              expenses.fold<double>(0, (acc, e) => acc + e.amount);
          final memberCount = widget.trip.paidMembers.length;
          final perPerson =
              memberCount > 0 ? total / memberCount : total;

          return Column(
            children: [
              // ── Summary card ──────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      RihlaColors.jungleGreenDark,
                      RihlaColors.jungleGreen
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(
                      label: ar ? 'الإجمالي' : 'Total',
                      value: '\$${total.toStringAsFixed(2)}',
                      fontFamily: fontFamily!,
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _SummaryItem(
                      label: ar ? 'للشخص' : 'Per Person',
                      value: '\$${perPerson.toStringAsFixed(2)}',
                      fontFamily: fontFamily,
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _SummaryItem(
                      label: ar ? 'أعضاء' : 'Members',
                      value: '$memberCount',
                      fontFamily: fontFamily,
                    ),
                  ],
                ),
              ),

              // ── Expense list ──────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, i) {
                    final e = expenses[i];
                    final isMe = e.paidBy == _uid;

                    return Dismissible(
                      key: Key(e.id),
                      direction: isMe
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_rounded,
                            color: Colors.red),
                      ),
                      onDismissed: (_) =>
                          _expenses.doc(e.id).delete(),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: RihlaColors.sunsetOrange
                                .withValues(alpha: 0.15),
                            child: Icon(Icons.receipt_long_rounded,
                                color: RihlaColors.sunsetOrange, size: 20),
                          ),
                          title: Text(
                            e.description,
                            style: TextStyle(
                                fontFamily: fontFamily,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${ar ? "دفعها" : "Paid by"} ${isMe ? (ar ? "أنت" : "You") : e.paidByName}',
                            style: TextStyle(
                                fontSize: 12,
                                color: headingColor.withValues(alpha: 0.6)),
                          ),
                          trailing: Text(
                            '\$${e.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily: GoogleFonts.pangolin().fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: RihlaColors.sunsetOrange,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.fontFamily,
  });
  final String label;
  final String value;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                color: Colors.white70)),
      ],
    );
  }
}
