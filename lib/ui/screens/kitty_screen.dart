import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../services/kitty_service.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';

// ─────────────────────────────────────────────────
//  Arabic detection helper
// ─────────────────────────────────────────────────
final _arabicRe = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

bool _containsArabic(String text) => _arabicRe.hasMatch(text);

TextDirection _detectDirection(String text) =>
    _containsArabic(text) ? TextDirection.rtl : TextDirection.ltr;

// ═════════════════════════════════════════════════
//  KittyScreen
// ═════════════════════════════════════════════════
class KittyScreen extends StatefulWidget {
  const KittyScreen({
    super.key,
    required this.trip,
    this.onTripUpdated,
  });
  final Trip trip;
  final ValueChanged<Trip>? onTripUpdated;

  @override
  State<KittyScreen> createState() => _KittyScreenState();
}

class _KittyScreenState extends State<KittyScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _baseCurrency = 'OMR';
  bool _loadingCurrency = true;
  Map<String, String> _names = {};
  List<String> _lastMemberUids = [];

  // Cache streams so StreamBuilder doesn't re-subscribe on every build
  late final Stream<Trip?> _tripStream;
  late final Stream<List<Expense>> _expensesStream;

  String get _myUid => TripService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _tripStream = TripService.instance.tripStream(widget.trip.id);
    _expensesStream = KittyService.instance.expensesStream(widget.trip.id);
    _loadBaseCurrency();
    _loadNames(widget.trip.paidMembers);
  }

  Future<void> _loadBaseCurrency() async {
    final bc = await KittyService.instance.getBaseCurrency(widget.trip.id);
    if (mounted) setState(() { _baseCurrency = bc; _loadingCurrency = false; });
  }

  Future<void> _loadNames(List<String> uids) async {
    // Clear cache so stale "Member xxxxx" entries are refreshed
    TripService.instance.clearNameCache();
    final names = await TripService.instance.resolveNames(uids);
    if (mounted) setState(() { _names = names; _lastMemberUids = uids; });
  }

  String _name(String uid) {
    if (uid == _myUid) return AppSettings.of(context).isArabic ? 'أنت' : 'You';
    return _names[uid] ?? TripService.instance.getCachedName(uid);
  }

  // ── Set base currency (admin) ───────────────
  Future<void> _changeBaseCurrency(Trip trip) async {
    if (!trip.isAdmin(_myUid)) return;
    final ar = AppSettings.of(context).isArabic;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyTypeahead(
        currentCode: _baseCurrency,
        isArabic: ar,
        title: ar ? 'العملة الأساسية' : 'Base Currency',
      ),
    );
    if (result != null && result != _baseCurrency) {
      await KittyService.instance.setBaseCurrency(trip.id, result);
      setState(() => _baseCurrency = result);
    }
  }

  // ── Add expense ─────────────────────────────
  Future<void> _addExpense(Trip trip) async {
    if (trip.isSettled) return;
    final ar = AppSettings.of(context).isArabic;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(
        tripId: trip.id,
        baseCurrency: _baseCurrency,
        members: trip.paidMembers,
        names: _names,
        isArabic: ar,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'تم إضافة المصروف' : 'Expense added'),
          backgroundColor: R.success,
        ),
      );
    }
  }

  // ── Edit expense ────────────────────────────
  Future<void> _editExpense(Trip trip, Expense expense) async {
    if (trip.isSettled) return;
    final canEdit = expense.paidByUid == _myUid || trip.isAdmin(_myUid);
    if (!canEdit) return;

    final ar = AppSettings.of(context).isArabic;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(
        tripId: trip.id,
        baseCurrency: _baseCurrency,
        members: trip.paidMembers,
        names: _names,
        isArabic: ar,
        existingExpense: expense,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar ? 'تم تحديث المصروف' : 'Expense updated'),
          backgroundColor: R.success,
        ),
      );
    }
  }

  // ── Delete expense ──────────────────────────
  Future<void> _deleteExpense(Trip trip, Expense expense) async {
    if (trip.isSettled) return;
    final ar = AppSettings.of(context).isArabic;
    final isAdmin = trip.isAdmin(_myUid);
    final name = _name(expense.paidByUid);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'حذف المصروف؟' : 'Delete expense?'),
        content: Text(ar
            ? 'هل أنت متأكد من حذف "${expense.description}" بواسطة $name؟'
            : 'Are you sure you want to delete "${expense.description}" by $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'حذف' : 'Delete',
                style: const TextStyle(color: R.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await KittyService.instance.deleteExpense(
      trip.id, expense, isAdmin: isAdmin);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ar
              ? 'يمكنك حذف مصاريفك فقط'
              : 'You can only delete your own expenses'),
          backgroundColor: R.error,
        ),
      );
    }
  }

  // ── Settle / Unsettle ─────────────────────────
  Future<void> _toggleSettle(Trip trip) async {
    final isAdmin = trip.isAdmin(_myUid);
    if (!isAdmin) return;
    final ar = AppSettings.of(context).isArabic;

    if (trip.isSettled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ar ? 'إعادة فتح الحسابات؟' : 'Reopen Kitty?'),
          content: Text(ar
              ? 'سيتمكن الجميع من إضافة وتعديل المصاريف مجددًا'
              : 'Everyone will be able to add and edit expenses again'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text(ar ? 'إلغاء' : 'Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text(ar ? 'فتح' : 'Reopen')),
          ],
        ),
      );
      if (confirmed != true) return;
      await TripService.instance.unsettleTrip(trip.id);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ar ? 'تسوية وإغلاق الحسابات؟' : 'Settle & Close Kitty?'),
          content: Text(ar
              ? 'سيتم تجميد جميع المصاريف. لن يتمكن أحد من الإضافة أو التعديل.'
              : 'All expenses will be frozen. No one can add or edit expenses.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text(ar ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: R.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'تسوية وإغلاق' : 'Settle & Close'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await TripService.instance.settleTrip(trip.id);
    }
    // No need to call onTripUpdated — the StreamBuilder will pick it up
  }

  // ═══════════════════════════════════════════════
  //  BUILD — wrapped in TWO StreamBuilders:
  //    1. Trip doc (real-time settle/members)
  //    2. Expenses (real-time add/edit/delete)
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ar = AppSettings.of(context).isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loadingCurrency) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    // Outer stream: trip document (settle state, members, etc.)
    return StreamBuilder<Trip?>(
      stream: _tripStream,
      builder: (context, tripSnap) {
        final trip = tripSnap.data ?? widget.trip;
        final isAdmin = trip.isAdmin(_myUid);
        final isSettled = trip.isSettled;

        // Sync trip changes to parent
        if (tripSnap.hasData && tripSnap.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onTripUpdated?.call(trip);
          });
        }

        // Re-resolve names if member list changed
        final currentUids = trip.paidMembers;
        if (currentUids.length != _lastMemberUids.length ||
            !currentUids.every((uid) => _lastMemberUids.contains(uid))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadNames(currentUids);
          });
        }

        // Inner stream: expenses (cached, same object across builds)
        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, expSnap) {
            final allExpenses = expSnap.data ?? [];

            // Filter: hide expenses the user is not involved in
            final expenses = allExpenses.where((e) {
              if (isAdmin) return true;
              if (e.paidByUid == _myUid) return true;
              if (e.splitAmong.contains(_myUid)) return true;
              return false;
            }).toList();

            final totalBase = allExpenses.fold<double>(
                0.0, (sum, e) => sum + e.amountInBase);
            final settlements = KittyService.instance.calculateSettlements(
              allExpenses,
              trip.members,
              nameMap: _names,
            );

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // ── Settled banner ────────────────
                    if (isSettled)
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          color: R.success.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded,
                                  color: R.success, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ar
                                      ? 'تمت التسوية — الحسابات مغلقة'
                                      : 'Settled — Kitty is closed',
                                  style: tt.bodyMedium?.copyWith(
                                    color: R.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isAdmin)
                                TextButton(
                                  onPressed: () => _toggleSettle(trip),
                                  child: Text(ar ? 'إعادة فتح' : 'Reopen',
                                      style: const TextStyle(color: R.success)),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // ── Summary card ────────────────
                    SliverToBoxAdapter(
                      child: _SummaryCard(
                        totalBase: totalBase,
                        baseCurrency: _baseCurrency,
                        expenseCount: allExpenses.length,
                        memberCount: trip.paidMembers.length,
                        isAdmin: isAdmin,
                        isArabic: ar,
                        cs: cs,
                        tt: tt,
                        onChangeCurrency: () => _changeBaseCurrency(trip),
                      ),
                    ),

                    // ── Admin settle button ─────────
                    if (isAdmin && !isSettled && allExpenses.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: R.error,
                              side: const BorderSide(color: R.error),
                            ),
                            onPressed: () => _toggleSettle(trip),
                            icon: const Icon(Icons.gavel_rounded, size: 18),
                            label: Text(ar
                                ? 'تسوية وإغلاق الحسابات'
                                : 'Settle & Close Trip'),
                          ),
                        ),
                      ),

                    // ── Settlement actions ──────────
                    if (settlements.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Icon(Icons.handshake_rounded,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                ar
                                    ? 'التسويات (${settlements.length})'
                                    : 'Settlements (${settlements.length})',
                                style: tt.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
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
                            isArabic: ar,
                            cs: cs,
                            tt: tt,
                            myUid: _myUid,
                          ),
                          childCount: settlements.length,
                        ),
                      ),
                    ],

                    // ── Expenses header ─────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                color: cs.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              ar
                                  ? 'المصاريف (${expenses.length})'
                                  : 'Expenses (${expenses.length})',
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                                    color: cs.onSurface.withValues(alpha: 0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  ar ? 'لا توجد مصاريف بعد' : 'No expenses yet',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5),
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
                            final canEdit = !isSettled && (isMe || isAdmin);
                            final canDelete = !isSettled && (isMe || isAdmin);

                            return _ExpenseTile(
                              expense: e,
                              category: cat,
                              baseCurrency: _baseCurrency,
                              isArabic: ar,
                              cs: cs,
                              tt: tt,
                              payerName: _name(e.paidByUid),
                              isMe: isMe,
                              onTap: canEdit
                                  ? () => _editExpense(trip, e)
                                  : null,
                              onDelete: canDelete
                                  ? () => _deleteExpense(trip, e)
                                  : null,
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
                if (!isSettled)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'add_expense',
                      icon: const Icon(Icons.add_rounded),
                      label: Text(ar ? 'مصروف جديد' : 'Add Expense'),
                      onPressed: () => _addExpense(trip),
                    ),
                  ),
              ],
            );
          },
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
    required this.isArabic,
    required this.cs,
    required this.tt,
    required this.onChangeCurrency,
  });

  final double totalBase;
  final String baseCurrency;
  final int expenseCount;
  final int memberCount;
  final bool isAdmin;
  final bool isArabic;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onChangeCurrency;

  @override
  Widget build(BuildContext context) {
    final perPerson = memberCount > 0 ? totalBase / memberCount : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(R.radiusXl),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(R.radiusMd),
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
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${totalBase.toStringAsFixed(2)} $baseCurrency',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
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
                    borderRadius: BorderRadius.circular(R.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(R.radiusMd),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(baseCurrency,
                              style: tt.labelLarge
                                  ?.copyWith(color: cs.primary)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              size: 14, color: cs.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(Icons.receipt_rounded,
                  isArabic ? 'مصاريف' : 'Expenses', '$expenseCount', cs, tt),
              _StatChip(Icons.people_rounded,
                  isArabic ? 'أعضاء' : 'Members', '$memberCount', cs, tt),
              _StatChip(Icons.person_rounded,
                  isArabic ? 'لكل شخص' : 'Per Person',
                  perPerson.toStringAsFixed(1), cs, tt),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.icon, this.label, this.value, this.cs, this.tt);
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(value, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: tt.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5))),
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
    required this.isArabic,
    required this.cs,
    required this.tt,
    required this.myUid,
  });
  final Settlement settlement;
  final String baseCurrency;
  final bool isArabic;
  final ColorScheme cs;
  final TextTheme tt;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isFromMe = settlement.fromUid == myUid;
    final isToMe = settlement.toUid == myUid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        color: isFromMe
            ? R.error.withValues(alpha: 0.04)
            : isToMe
                ? R.success.withValues(alpha: 0.04)
                : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: R.error.withValues(alpha: 0.1),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: R.error, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: tt.bodyMedium,
                    children: [
                      TextSpan(
                        text: isFromMe
                            ? (isArabic ? 'أنت' : 'You')
                            : settlement.fromName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: isArabic ? ' يدفع ' : ' pays '),
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
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(R.radiusMd),
                ),
                child: Text(
                  '${settlement.amount.toStringAsFixed(2)} $baseCurrency',
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
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
    required this.isArabic,
    required this.cs,
    required this.tt,
    required this.payerName,
    required this.isMe,
    this.onTap,
    this.onDelete,
  });
  final Expense expense;
  final ExpenseCategory category;
  final String baseCurrency;
  final bool isArabic;
  final ColorScheme cs;
  final TextTheme tt;
  final String payerName;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final descDirection = _detectDirection(expense.description);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(category.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Text(
            expense.description,
            textDirection: descDirection,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$payerName · ${isArabic ? category.labelAr : category.labelEn}'
            ' · ${expense.splitAmong.length} ${isArabic ? "أشخاص" : "people"}',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (expense.currency != baseCurrency)
                    Text(
                      '≈ ${expense.amountInBase.toStringAsFixed(2)} $baseCurrency',
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              // Explicit delete icon for owner/admin
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: R.error, size: 20),
                  tooltip: isArabic ? 'حذف' : 'Delete',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════
//  Smart Currency Typeahead (shared by base-currency
//  picker AND the expense currency field)
//
//  Searches by: currency code, name, or country.
//  When empty: shows Top 10 + Gulf first, then rest.
// ═════════════════════════════════════════════════
class _CurrencyTypeahead extends StatefulWidget {
  const _CurrencyTypeahead({
    required this.currentCode,
    required this.isArabic,
    this.title,
  });
  final String currentCode;
  final bool isArabic;
  final String? title;

  @override
  State<_CurrencyTypeahead> createState() => _CurrencyTypeaheadState();
}

class _CurrencyTypeaheadState extends State<_CurrencyTypeahead> {
  final _searchCtrl = TextEditingController();
  List<CurrencyInfo> _results = [];
  final _priorityCodes = <String>{...kTopCurrencyCodes, ...kGulfCurrencyCodes};

  @override
  void initState() {
    super.initState();
    _results = defaultSuggestions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _results = defaultSuggestions();
      } else {
        _results = searchCurrencies(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ar = widget.isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Split results into priority and other for section headers
    final priorityResults =
        _results.where((c) => _priorityCodes.contains(c.code)).toList();
    final otherResults =
        _results.where((c) => !_priorityCodes.contains(c.code)).toList();
    final isSearching = _searchCtrl.text.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              widget.title ?? (ar ? 'اختر العملة' : 'Select Currency'),
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          // ── Search field ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: ar
                    ? 'ابحث: اسم الدولة أو رمز العملة...'
                    : 'Search: country name or currency code...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          // ── Results ──
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      ar ? 'لا توجد نتائج' : 'No results found',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      // When searching, show flat list. Otherwise show sections.
                      if (!isSearching && priorityResults.isNotEmpty) ...[
                        _sectionHeader(
                          ar ? 'العملات الشائعة' : 'Popular Currencies',
                          tt,
                        ),
                        ...priorityResults
                            .map((c) => _currencyTile(c, cs, tt)),
                        if (otherResults.isNotEmpty)
                          _sectionHeader(
                            ar ? 'عملات أخرى' : 'Other Currencies',
                            tt,
                          ),
                        ...otherResults
                            .map((c) => _currencyTile(c, cs, tt)),
                      ] else
                        ..._results.map((c) => _currencyTile(c, cs, tt)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 20),
      child: Text(title,
          style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Widget _currencyTile(CurrencyInfo info, ColorScheme cs, TextTheme tt) {
    final isSelected = info.code == widget.currentCode;
    final countryHint = info.countries.isNotEmpty
        ? info.countries.take(2).join(', ')
        : null;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            info.code,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isSelected ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
      title: Text(
        info.name,
        style: tt.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? cs.primary : null,
        ),
      ),
      subtitle: countryHint != null
          ? Text(countryHint,
              style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5)))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.symbol.isNotEmpty)
            Text(info.symbol,
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          if (isSelected) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle_rounded,
                color: cs.primary, size: 18),
          ],
        ],
      ),
      onTap: () => Navigator.pop(context, info.code),
    );
  }
}

// ═════════════════════════════════════════════════
//  Add / Edit Expense Bottom Sheet
// ═════════════════════════════════════════════════
class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    required this.tripId,
    required this.baseCurrency,
    required this.members,
    required this.names,
    required this.isArabic,
    this.existingExpense,
  });
  final String tripId;
  final String baseCurrency;
  final List<String> members;
  final Map<String, String> names;
  final bool isArabic;
  final Expense? existingExpense; // null = add, non-null = edit

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _currency = 'OMR';
  String _category = 'other';
  late Set<String> _splitAmong;
  bool _saving = false;
  TextDirection _descDirection = TextDirection.ltr;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _currency = widget.baseCurrency;
    _splitAmong = widget.members.toSet();

    // Pre-populate for edit mode
    if (_isEditing) {
      final e = widget.existingExpense!;
      _descCtrl.text = e.description;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _currency = e.currency;
      _category = e.category;
      _splitAmong = e.splitAmong.toSet();
      _descDirection = _detectDirection(e.description);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _nameForUid(String uid) {
    final myUid = TripService.instance.currentUserId;
    if (uid == myUid) return widget.isArabic ? 'أنت' : 'You';
    return widget.names[uid] ?? TripService.instance.getCachedName(uid);
  }

  void _onDescriptionChanged(String value) {
    // Auto-detect category from text
    final suggested = suggestCategory(value);
    if (suggested != _category) {
      setState(() => _category = suggested);
    }
    // Auto-detect Arabic for RTL
    final dir = _detectDirection(value);
    if (dir != _descDirection) {
      setState(() => _descDirection = dir);
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
          backgroundColor: R.error,
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
          backgroundColor: R.error,
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

      if (_isEditing) {
        await KittyService.instance.updateExpense(
          tripId: widget.tripId,
          expenseId: widget.existingExpense!.id,
          description: desc,
          category: _category,
          amount: amount,
          currency: _currency,
          amountInBase: amountInBase,
          splitAmong: _splitAmong.toList(),
        );
      } else {
        await KittyService.instance.addExpense(
          tripId: widget.tripId,
          description: desc,
          category: _category,
          amount: amount,
          currency: _currency,
          amountInBase: amountInBase,
          splitAmong: _splitAmong.toList(),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: R.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cat = categoryByKey(_category);

    final currencyInfo = kCurrencyMap[_currency];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(
              _isEditing
                  ? (ar ? 'تعديل المصروف' : 'Edit Expense')
                  : (ar ? 'مصروف جديد' : 'New Expense'),
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── Description (smart search + Arabic detection) ──
            TextField(
              controller: _descCtrl,
              onChanged: _onDescriptionChanged,
              textDirection: _descDirection,
              decoration: InputDecoration(
                labelText:
                    ar ? 'الوصف (مثل: عشاء)' : 'Description (e.g. Dinner)',
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
                      style: tt.labelSmall,
                    ),
                    backgroundColor: cs.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
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
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CurrencyTypeahead(
                          currentCode: _currency,
                          isArabic: ar,
                        ),
                      );
                      if (result != null) {
                        setState(() => _currency = result);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: ar ? 'العملة' : 'Currency',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        suffixIcon: const Icon(Icons.search_rounded, size: 18),
                      ),
                      child: Text(
                        currencyInfo != null
                            ? '$_currency (${currencyInfo.symbol})'
                            : _currency,
                        style: tt.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  style: tt.bodySmall?.copyWith(color: cs.primary),
                ),
              ),
            const SizedBox(height: 16),

            // ── Category chips ─────────────────
            Text(ar ? 'الفئة' : 'Category', style: tt.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kExpenseCategories.map((c) {
                final isSelected = c.key == _category;
                return ChoiceChip(
                  label: Text(
                    '${c.emoji} ${ar ? c.labelAr : c.labelEn}',
                    style: tt.labelSmall?.copyWith(
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _category = c.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── "Who is this for?" multi-select ──
            Text(
              ar ? 'من يشارك في هذا المصروف؟' : 'Who is this for?',
              style: tt.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.members.map((uid) {
                final isSelected = _splitAmong.contains(uid);
                final name = _nameForUid(uid);
                return FilterChip(
                  label: Text(
                    name,
                    style: tt.labelSmall?.copyWith(
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  selected: isSelected,
                  checkmarkColor: Colors.white,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _splitAmong = widget.members.toSet()),
                  child: Text(ar ? 'الكل' : 'All', style: tt.labelSmall),
                ),
                TextButton(
                  onPressed: () => setState(() => _splitAmong.clear()),
                  child: Text(ar ? 'لا أحد' : 'None', style: tt.labelSmall),
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
                        _isEditing
                            ? (ar ? 'تحديث المصروف' : 'Update Expense')
                            : (ar ? 'حفظ المصروف' : 'Save Expense'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
