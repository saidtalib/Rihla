import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../services/kitty_service.dart';
import '../../services/trip_service.dart';

/// The Kitty expense-splitting screen.
class KittyScreen extends StatefulWidget {
  const KittyScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<KittyScreen> createState() => _KittyScreenState();
}

class _KittyScreenState extends State<KittyScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _baseCurrency = 'OMR';
  bool _loadingCurrency = true;

  String get _myUid => TripService.instance.currentUserId;
  bool get _isAdmin => TripService.instance.currentUserIsAdmin(widget.trip);

  @override
  void initState() {
    super.initState();
    _loadBaseCurrency();
  }

  Future<void> _loadBaseCurrency() async {
    final bc =
        await KittyService.instance.getBaseCurrency(widget.trip.id);
    if (mounted) {
      setState(() {
        _baseCurrency = bc;
        _loadingCurrency = false;
      });
    }
  }

  // ── Set base currency (admin) ───────────────
  Future<void> _changeBaseCurrency() async {
    final ar = AppSettings.of(context).isArabic;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CurrencyPickerDialog(
        currentCurrency: _baseCurrency,
        isArabic: ar,
      ),
    );
    if (result != null && result != _baseCurrency) {
      await KittyService.instance
          .setBaseCurrency(widget.trip.id, result);
      setState(() => _baseCurrency = result);
    }
  }

  // ── Add expense ─────────────────────────────
  Future<void> _addExpense() async {
    final ar = AppSettings.of(context).isArabic;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        tripId: widget.trip.id,
        baseCurrency: _baseCurrency,
        members: widget.trip.paidMembers,
        membersMap: widget.trip.members,
        isArabic: ar,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'تم إضافة المصروف' : 'Expense added'),
          backgroundColor: RihlaColors.jungleGreen,
        ),
      );
    }
  }

  // ── Delete expense ──────────────────────────
  Future<void> _deleteExpense(Expense expense) async {
    final ar = AppSettings.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف المصروف؟' : 'Delete expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'حذف' : 'Delete',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await KittyService.instance.deleteExpense(
      widget.trip.id,
      expense,
      isAdmin: _isAdmin,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar
              ? 'يمكنك حذف مصاريفك فقط'
              : 'You can only delete your own expenses'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    if (_loadingCurrency) {
      return const Center(
          child: CircularProgressIndicator(color: RihlaColors.jungleGreen));
    }

    return StreamBuilder<List<Expense>>(
      stream: KittyService.instance.expensesStream(widget.trip.id),
      builder: (context, snap) {
        final expenses = snap.data ?? [];
        final totalBase = expenses.fold<double>(
            0.0, (sum, e) => sum + e.amountInBase);
        final settlements = KittyService.instance.calculateSettlements(
          expenses,
          widget.trip.members,
        );

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Summary card ────────────────
                SliverToBoxAdapter(
                  child: _SummaryCard(
                    totalBase: totalBase,
                    baseCurrency: _baseCurrency,
                    expenseCount: expenses.length,
                    memberCount: widget.trip.paidMembers.length,
                    isAdmin: _isAdmin,
                    isDark: dark,
                    isArabic: ar,
                    fontFamily: fontFamily!,
                    onChangeCurrency: _changeBaseCurrency,
                  ),
                ),

                // ── Settlement actions ──────────
                if (settlements.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.handshake_rounded,
                              color: RihlaColors.sunsetOrange,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            ar
                                ? 'التسويات (${settlements.length})'
                                : 'Settlements (${settlements.length})',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: dark
                                  ? RihlaColors.saharaSand
                                  : RihlaColors.jungleGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _SettlementTile(
                        settlement: settlements[i],
                        baseCurrency: _baseCurrency,
                        isDark: dark,
                        isArabic: ar,
                        fontFamily: fontFamily,
                        myUid: _myUid,
                      ),
                      childCount: settlements.length,
                    ),
                  ),
                ],

                // ── Expenses list ───────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            color: RihlaColors.sunsetOrange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          ar
                              ? 'المصاريف (${expenses.length})'
                              : 'Expenses (${expenses.length})',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: dark
                                ? RihlaColors.saharaSand
                                : RihlaColors.jungleGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                size: 56,
                                color: RihlaColors.jungleGreen
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              ar
                                  ? 'لا توجد مصاريف بعد'
                                  : 'No expenses yet',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                color: (dark
                                        ? RihlaColors.darkText
                                        : RihlaColors.jungleGreenDark)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final e = expenses[i];
                        final cat = categoryByKey(e.category);
                        final isMe = e.paidByUid == _myUid;
                        return Dismissible(
                          key: ValueKey(e.id),
                          direction: (isMe || _isAdmin)
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.only(right: 24),
                            color: Colors.red,
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteExpense(e),
                          child: _ExpenseTile(
                            expense: e,
                            category: cat,
                            baseCurrency: _baseCurrency,
                            isDark: dark,
                            isArabic: ar,
                            fontFamily: fontFamily,
                            isMe: isMe,
                          ),
                        );
                      },
                      childCount: expenses.length,
                    ),
                  ),

                // Bottom padding for FAB
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),

            // ── FAB: Add Expense ─────────────
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'add_expense',
                backgroundColor: RihlaColors.jungleGreen,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  ar ? 'مصروف جديد' : 'Add Expense',
                  style: TextStyle(
                      fontFamily: fontFamily, fontWeight: FontWeight.w700),
                ),
                onPressed: _addExpense,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════
//  Summary Card
// ═════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalBase,
    required this.baseCurrency,
    required this.expenseCount,
    required this.memberCount,
    required this.isAdmin,
    required this.isDark,
    required this.isArabic,
    required this.fontFamily,
    required this.onChangeCurrency,
  });

  final double totalBase;
  final String baseCurrency;
  final int expenseCount;
  final int memberCount;
  final bool isAdmin;
  final bool isDark;
  final bool isArabic;
  final String fontFamily;
  final VoidCallback onChangeCurrency;

  @override
  Widget build(BuildContext context) {
    final perPerson =
        memberCount > 0 ? totalBase / memberCount : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [RihlaColors.darkCard, RihlaColors.darkSurface]
              : [RihlaColors.saharaSand, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFFD700), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'إجمالي المصاريف' : 'Total Spent',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        color: (isDark
                                ? RihlaColors.darkText
                                : RihlaColors.jungleGreenDark)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${totalBase.toStringAsFixed(2)} $baseCurrency',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? RihlaColors.saharaSand
                            : RihlaColors.jungleGreen,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Tooltip(
                  message: isArabic
                      ? 'تغيير العملة الأساسية'
                      : 'Change base currency',
                  child: InkWell(
                    onTap: onChangeCurrency,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: RihlaColors.jungleGreen
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RihlaColors.jungleGreen
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            baseCurrency,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: RihlaColors.jungleGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_rounded,
                              size: 14,
                              color: RihlaColors.jungleGreen),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                icon: Icons.receipt_rounded,
                label: isArabic ? 'مصاريف' : 'Expenses',
                value: '$expenseCount',
                fontFamily: fontFamily,
                isDark: isDark,
              ),
              _StatChip(
                icon: Icons.people_rounded,
                label: isArabic ? 'أعضاء' : 'Members',
                value: '$memberCount',
                fontFamily: fontFamily,
                isDark: isDark,
              ),
              _StatChip(
                icon: Icons.person_rounded,
                label: isArabic ? 'لكل شخص' : 'Per Person',
                value: perPerson.toStringAsFixed(1),
                fontFamily: fontFamily,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.fontFamily,
    required this.isDark,
  });
  final IconData icon;
  final String label;
  final String value;
  final String fontFamily;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            size: 18,
            color: RihlaColors.sunsetOrange.withValues(alpha: 0.8)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color:
                isDark ? RihlaColors.darkText : RihlaColors.jungleGreenDark,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            color: (isDark
                    ? RihlaColors.darkText
                    : RihlaColors.jungleGreenDark)
                .withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════
//  Settlement Tile
// ═════════════════════════════════════════════════
class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.settlement,
    required this.baseCurrency,
    required this.isDark,
    required this.isArabic,
    required this.fontFamily,
    required this.myUid,
  });
  final Settlement settlement;
  final String baseCurrency;
  final bool isDark;
  final bool isArabic;
  final String fontFamily;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isFromMe = settlement.fromUid == myUid;
    final isToMe = settlement.toUid == myUid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        color: isFromMe
            ? Colors.red.withValues(alpha: 0.05)
            : isToMe
                ? Colors.green.withValues(alpha: 0.05)
                : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // From avatar
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    Colors.red.withValues(alpha: 0.12),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.red, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 14,
                      color: isDark
                          ? RihlaColors.darkText
                          : RihlaColors.jungleGreenDark,
                    ),
                    children: [
                      TextSpan(
                        text: isFromMe
                            ? (isArabic ? 'أنت' : 'You')
                            : settlement.fromName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                          text: isArabic ? ' يدفع ' : ' pays '),
                      TextSpan(
                        text: isToMe
                            ? (isArabic ? 'أنت' : 'You')
                            : settlement.toName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: RihlaColors.sunsetOrange
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${settlement.amount.toStringAsFixed(2)} $baseCurrency',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: RihlaColors.sunsetOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════
//  Expense Tile
// ═════════════════════════════════════════════════
class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.category,
    required this.baseCurrency,
    required this.isDark,
    required this.isArabic,
    required this.fontFamily,
    required this.isMe,
  });
  final Expense expense;
  final ExpenseCategory category;
  final String baseCurrency;
  final bool isDark;
  final bool isArabic;
  final String fontFamily;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RihlaColors.sunsetOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(category.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Text(
            expense.description,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${isMe ? (isArabic ? "أنت" : "You") : expense.paidByName} · ${isArabic ? category.labelAr : category.labelEn}',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              color: (isDark
                      ? RihlaColors.darkText
                      : RihlaColors.jungleGreenDark)
                  .withValues(alpha: 0.5),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color:
                      isDark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                ),
              ),
              if (expense.currency != baseCurrency)
                Text(
                  '≈ ${expense.amountInBase.toStringAsFixed(2)} $baseCurrency',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    color: RihlaColors.sunsetOrange.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════
//  Currency Picker Dialog
// ═════════════════════════════════════════════════
class _CurrencyPickerDialog extends StatefulWidget {
  const _CurrencyPickerDialog({
    required this.currentCurrency,
    required this.isArabic,
  });
  final String currentCurrency;
  final bool isArabic;

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  late String _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCurrency;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kCommonCurrencies
        .where((c) => c.contains(_search.toUpperCase()))
        .toList();

    return AlertDialog(
      title: Text(widget.isArabic
          ? 'العملة الأساسية'
          : 'Base Currency'),
      content: SizedBox(
        width: 280,
        height: 350,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: widget.isArabic ? 'بحث...' : 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final isSelected = c == _selected;
                  return ListTile(
                    title: Text(c),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? RihlaColors.jungleGreen
                          : Colors.grey,
                    ),
                    onTap: () => setState(() => _selected = c),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(widget.isArabic ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(widget.isArabic ? 'حفظ' : 'Save')),
      ],
    );
  }
}

// ═════════════════════════════════════════════════
//  Add Expense Bottom Sheet
// ═════════════════════════════════════════════════
class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({
    required this.tripId,
    required this.baseCurrency,
    required this.members,
    required this.membersMap,
    required this.isArabic,
  });
  final String tripId;
  final String baseCurrency;
  final List<String> members;
  final Map<String, String> membersMap;
  final bool isArabic;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _currency = 'OMR';
  String _category = 'other';
  late Set<String> _splitAmong;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.baseCurrency;
    _splitAmong = widget.members.toSet();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onDescriptionChanged(String value) {
    final suggested = suggestCategory(value);
    if (suggested != _category) {
      setState(() => _category = suggested);
    }
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (desc.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isArabic
              ? 'أدخل الوصف والمبلغ'
              : 'Enter description and amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_splitAmong.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isArabic
              ? 'اختر عضوًا واحدًا على الأقل'
              : 'Select at least one member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final amountInBase = await KittyService.instance.convert(
        amount: amount,
        fromCurrency: _currency,
        baseCurrency: widget.baseCurrency,
      );

      await KittyService.instance.addExpense(
        tripId: widget.tripId,
        description: desc,
        category: _category,
        amount: amount,
        currency: _currency,
        amountInBase: amountInBase,
        splitAmong: _splitAmong.toList(),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    final dark = AppSettings.of(context).isDarkMode;
    final fontFamily = ar
        ? GoogleFonts.cairo().fontFamily
        : GoogleFonts.pangolin().fontFamily;
    final cat = categoryByKey(_category);

    return Container(
      decoration: BoxDecoration(
        color: dark ? RihlaColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(
              ar ? 'مصروف جديد' : 'New Expense',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: dark
                    ? RihlaColors.saharaSand
                    : RihlaColors.jungleGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── Description (smart search) ────
            TextField(
              controller: _descCtrl,
              onChanged: _onDescriptionChanged,
              decoration: InputDecoration(
                labelText: ar ? 'الوصف (مثل: عشاء)' : 'Description (e.g. Dinner)',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(cat.emoji,
                      style: const TextStyle(fontSize: 18)),
                ),
                suffixIcon: Tooltip(
                  message: ar ? cat.labelAr : cat.labelEn,
                  child: Chip(
                    label: Text(
                      ar ? cat.labelAr : cat.labelEn,
                      style: TextStyle(
                          fontFamily: fontFamily, fontSize: 11),
                    ),
                    backgroundColor: RihlaColors.sunsetOrange
                        .withValues(alpha: 0.12),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              style: TextStyle(fontFamily: fontFamily),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // ── Amount + Currency ──────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: ar ? 'المبلغ' : 'Amount',
                      prefixIcon: const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700)),
                    ),
                    style: TextStyle(fontFamily: fontFamily),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: ar ? 'العملة' : 'Currency',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: kCommonCurrencies
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 14,
                      color: dark
                          ? RihlaColors.darkText
                          : RihlaColors.jungleGreenDark,
                    ),
                  ),
                ),
              ],
            ),
            if (_currency != widget.baseCurrency)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  ar
                      ? '* سيتم التحويل تلقائيًا إلى ${widget.baseCurrency}'
                      : '* Will be auto-converted to ${widget.baseCurrency}',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    color: RihlaColors.sunsetOrange,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ── Category chips ─────────────────
            Text(
              ar ? 'الفئة' : 'Category',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: dark
                    ? RihlaColors.darkText
                    : RihlaColors.jungleGreenDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kExpenseCategories.map((c) {
                final isSelected = c.key == _category;
                return ChoiceChip(
                  label: Text(
                    '${c.emoji} ${ar ? c.labelAr : c.labelEn}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : (dark
                              ? RihlaColors.darkText
                              : RihlaColors.jungleGreenDark),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: RihlaColors.jungleGreen,
                  backgroundColor: dark
                      ? RihlaColors.darkCard
                      : RihlaColors.saharaSand,
                  onSelected: (_) =>
                      setState(() => _category = c.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Split among ───────────────────
            Text(
              ar ? 'تقسيم بين' : 'Split among',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: dark
                    ? RihlaColors.darkText
                    : RihlaColors.jungleGreenDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.members.map((uid) {
                final isSelected = _splitAmong.contains(uid);
                final isMe =
                    uid == TripService.instance.currentUserId;
                final label = isMe
                    ? (ar ? 'أنت' : 'You')
                    : '${ar ? "عضو" : ""} ${uid.substring(0, 6)}';
                return FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : (dark
                              ? RihlaColors.darkText
                              : RihlaColors.jungleGreenDark),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: RihlaColors.jungleGreen,
                  checkmarkColor: Colors.white,
                  backgroundColor: dark
                      ? RihlaColors.darkCard
                      : RihlaColors.saharaSand,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _splitAmong.add(uid);
                      } else {
                        _splitAmong.remove(uid);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Select all / deselect
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(
                      () => _splitAmong = widget.members.toSet()),
                  child: Text(ar ? 'الكل' : 'All',
                      style: TextStyle(
                          fontFamily: fontFamily, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _splitAmong.clear()),
                  child: Text(ar ? 'لا أحد' : 'None',
                      style: TextStyle(
                          fontFamily: fontFamily, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Save button ───────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        ar ? 'حفظ المصروف' : 'Save Expense',
                        style: TextStyle(
                            fontFamily: fontFamily,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
