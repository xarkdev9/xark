import 'package:flutter/material.dart';
import 'package:xpensly_core/xpensly_core.dart';
import 'package:xpensly_ui/xpensly_ui.dart';

void main() {
  runApp(const XpenslyDemoApp());
}

// ---------------------------------------------------------------------------
// App root — manages theme
// ---------------------------------------------------------------------------

class XpenslyDemoApp extends StatefulWidget {
  const XpenslyDemoApp({super.key});

  @override
  State<XpenslyDemoApp> createState() => _XpenslyDemoAppState();
}

class _XpenslyDemoAppState extends State<XpenslyDemoApp> {
  String _themeName = 'hello';

  XpenslyThemeData get _theme {
    switch (_themeName) {
      case 'material':
        return XpenslyThemeData.material();
      case 'minimal':
        return XpenslyThemeData.minimal();
      default:
        return XpenslyThemeData.hello();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return MaterialApp(
      title: 'Xpensly Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: theme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primary,
          brightness:
              _themeName == 'hello' ? Brightness.dark : Brightness.light,
        ),
      ),
      home: XpenslyTheme(
        theme: theme,
        child: DemoHome(
          currentTheme: _themeName,
          onThemeChanged: (name) => setState(() => _themeName = name),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo home — data seeding, user perspective, dashboard composition
// ---------------------------------------------------------------------------

class DemoHome extends StatefulWidget {
  final String currentTheme;
  final ValueChanged<String> onThemeChanged;

  const DemoHome({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  late Xpensly _xpensly;
  String? _tripId;
  bool _loading = true;
  int _dashboardKey = 0; // bump to force dashboard reload

  // "You" perspective — which user is viewing
  String _currentUserId = 'ram';
  final _members = <Member>[
    const Member(id: 'ram', name: 'Ram'),
    const Member(id: 'sarah', name: 'Sarah'),
    const Member(id: 'alex', name: 'Alex'),
    const Member(id: 'priya', name: 'Priya'),
  ];

  Map<String, String> get _nameMap =>
      {for (final m in _members) m.id: m.name};

  String _currentUserName() => _nameMap[_currentUserId] ?? _currentUserId;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  Future<void> _seedData() async {
    final ds = InMemoryDataSource();
    const allIds = ['ram', 'sarah', 'alex', 'priya'];

    final trip = await ds.createTrip(Trip(
      id: '',
      title: 'Bali Adventure 2026',
      baseCurrency: 'USD',
      startDate: DateTime(2026, 3, 15),
      endDate: DateTime(2026, 3, 22),
      members: _members,
      categories: [
        'Food',
        'Transport',
        'Accommodation',
        'Activities',
        'Shopping',
        'Drinks',
      ],
      phases: [
        TripPhase(
          name: 'Ubud',
          startDate: DateTime(2026, 3, 15),
          endDate: DateTime(2026, 3, 18),
        ),
        TripPhase(
          name: 'Seminyak',
          startDate: DateTime(2026, 3, 18),
          endDate: DateTime(2026, 3, 22),
        ),
      ],
      settings: const TripSettings(
        simplifyDebts: true,
        defaultSplitMode: SplitMode.equal,
        baseCurrency: 'USD',
      ),
    ));

    final expenses = <Expense>[
      Expense(id: '', title: 'Airport taxi to Ubud', category: 'Transport', amount: 35.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 35.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 15), phase: 'Ubud'),
      Expense(id: '', title: 'Airbnb villa (3 nights)', category: 'Accommodation', amount: 480.00, currency: 'USD', paidBy: [const Payer(userId: 'sarah', amount: 480.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 15), phase: 'Ubud'),
      Expense(id: '', title: 'Welcome dinner at Locavore', category: 'Food', amount: 120.00, currency: 'USD', paidBy: [const Payer(userId: 'alex', amount: 120.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 15), phase: 'Ubud'),
      Expense(id: '', title: 'Tegallalang rice terrace tour', category: 'Activities', amount: 80.00, currency: 'USD', paidBy: [const Payer(userId: 'priya', amount: 80.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 16), phase: 'Ubud'),
      Expense(id: '', title: 'Lunch at Warung Biah Biah', category: 'Food', amount: 28.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 28.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 16), phase: 'Ubud'),
      Expense(id: '', title: 'Monkey Forest tickets', category: 'Activities', amount: 20.00, currency: 'USD', paidBy: [const Payer(userId: 'sarah', amount: 20.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 16), phase: 'Ubud'),
      Expense(id: '', title: 'Cocktails at sunset bar', category: 'Drinks', amount: 56.00, currency: 'USD', paidBy: [const Payer(userId: 'alex', amount: 56.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 16), phase: 'Ubud'),
      Expense(id: '', title: 'Spa & massage', category: 'Activities', amount: 100.00, currency: 'USD', paidBy: [const Payer(userId: 'priya', amount: 50.00), const Payer(userId: 'sarah', amount: 50.00)], splitAmong: ['priya', 'sarah', 'ram'], mode: SplitMode.equal, date: DateTime(2026, 3, 17), phase: 'Ubud'),
      Expense(id: '', title: 'Cooking class', category: 'Activities', amount: 160.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 160.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 17), phase: 'Ubud'),
      Expense(id: '', title: 'Private driver Ubud to Seminyak', category: 'Transport', amount: 45.00, currency: 'USD', paidBy: [const Payer(userId: 'alex', amount: 45.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 18), phase: 'Seminyak'),
      Expense(id: '', title: 'Beach hotel (4 nights)', category: 'Accommodation', amount: 720.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 720.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 18), phase: 'Seminyak'),
      Expense(id: '', title: 'Surfing lesson', category: 'Activities', amount: 120.00, currency: 'USD', paidBy: [const Payer(userId: 'sarah', amount: 120.00)], splitAmong: ['sarah', 'ram', 'alex'], mode: SplitMode.equal, date: DateTime(2026, 3, 19), phase: 'Seminyak'),
      Expense(id: '', title: 'Seafood BBQ dinner', category: 'Food', amount: 92.00, currency: 'USD', paidBy: [const Payer(userId: 'priya', amount: 92.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 19), phase: 'Seminyak'),
      Expense(id: '', title: 'Scooter rental (2 bikes)', category: 'Transport', amount: 30.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 30.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 20), phase: 'Seminyak'),
      Expense(id: '', title: 'Tanah Lot temple visit', category: 'Activities', amount: 24.00, currency: 'USD', paidBy: [const Payer(userId: 'alex', amount: 24.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 20), phase: 'Seminyak'),
      Expense(id: '', title: 'Souvenir shopping', category: 'Shopping', amount: 65.00, currency: 'USD', paidBy: [const Payer(userId: 'priya', amount: 65.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 20), phase: 'Seminyak'),
      Expense(id: '', title: 'Beach club day pass', category: 'Drinks', amount: 200.00, currency: 'USD', paidBy: [const Payer(userId: 'ram', amount: 100.00), const Payer(userId: 'alex', amount: 100.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 20), phase: 'Seminyak'),
      Expense(id: '', title: 'Farewell brunch', category: 'Food', amount: 75.00, currency: 'USD', paidBy: [const Payer(userId: 'sarah', amount: 75.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 21), phase: 'Seminyak'),
      Expense(id: '', title: 'Airport transfer', category: 'Transport', amount: 40.00, currency: 'USD', paidBy: [const Payer(userId: 'priya', amount: 40.00)], splitAmong: allIds, mode: SplitMode.equal, date: DateTime(2026, 3, 22), phase: 'Seminyak'),
    ];

    for (final e in expenses) {
      await ds.addExpense(trip.id, e);
    }

    _xpensly = Xpensly(
      dataSource: ds,
      paymentProviders: [const VenmoPayment(), const UpiPayment()],
      config: const XpenslyConfig(baseCurrency: 'USD', simplifyDebts: true),
    );

    setState(() {
      _tripId = trip.id;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Settle-up dialog
  // ---------------------------------------------------------------------------

  void _showSettleUpDialog(BuildContext ctx, DebtDelta delta, String providerName) {
    final theme = XpenslyTheme.of(ctx);
    final fromName = _nameMap[delta.from] ?? delta.from;
    final toName = _nameMap[delta.to] ?? delta.to;
    final link = _xpensly.getPaymentLink(
      providerName,
      from: delta.from,
      to: delta.to,
      amount: delta.amount,
      currency: delta.currency,
      note: 'Bali trip settle-up',
    );

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: theme.cardRadius),
        title: Text(
          'Settle up via $providerName',
          style: theme.titleStyle.copyWith(color: theme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: theme.bodyStyle.copyWith(color: theme.textPrimary),
                children: [
                  TextSpan(text: fromName),
                  TextSpan(
                    text: ' pays ',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  TextSpan(text: toName),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency(delta.amount, delta.currency),
              style: theme.amountStyle.copyWith(
                color: theme.primary,
                fontSize: 24,
              ),
            ),
            if (link != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  link,
                  style: theme.captionStyle.copyWith(color: theme.textSecondary),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: theme.bodyStyle.copyWith(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _xpensly.dataSource.recordSettlement(
                _tripId!,
                SettlementRecord(
                  id: '',
                  tripId: _tripId!,
                  fromUser: delta.from,
                  toUser: delta.to,
                  amount: delta.amount,
                  currency: delta.currency,
                  provider: providerName,
                  note: 'Bali trip settle-up',
                  settledAt: DateTime.now(),
                ),
              );
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              // Force dashboard to reload with new settlement data.
              setState(() => _dashboardKey++);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(
                  'Recorded: $fromName paid $toName '
                  '${formatCurrency(delta.amount, delta.currency)} via $providerName',
                ),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Text('Record payment',
                style: theme.bodyStyle.copyWith(color: theme.positive)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expense detail bottom sheet
  // ---------------------------------------------------------------------------

  void _showExpenseDetail(BuildContext ctx, Expense expense) {
    final theme = XpenslyTheme.of(ctx);
    final splitEngine = _xpensly.split;

    // Compute per-member share.
    final perMemberShare = <String, double>{};
    final count = expense.splitAmong.length;
    switch (expense.mode) {
      case SplitMode.equal:
        final share =
            ((expense.amount * 100).round() / count).roundToDouble() / 100;
        for (final uid in expense.splitAmong) {
          perMemberShare[uid] = share;
        }
        break;
      case SplitMode.exact:
      case SplitMode.percentage:
      case SplitMode.shares:
        if (expense.splitDetails != null) {
          perMemberShare.addAll(expense.splitDetails!);
        }
        break;
    }

    showModalBottomSheet(
      context: ctx,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: theme.cardRadius),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + amount
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style:
                          theme.titleStyle.copyWith(color: theme.textPrimary),
                    ),
                  ),
                  Text(
                    formatCurrency(expense.amount, expense.currency),
                    style: theme.amountStyle.copyWith(
                      color: theme.primary,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${expense.category}  \u2022  ${formatDate(expense.date)}'
                '${expense.phase != null ? '  \u2022  ${expense.phase}' : ''}',
                style: theme.captionStyle.copyWith(color: theme.textSecondary),
              ),
              if (expense.notes != null) ...[
                const SizedBox(height: 4),
                Text(
                  expense.notes!,
                  style: theme.captionStyle.copyWith(
                      color: theme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 16),

              // Paid by
              Text(
                'Paid by',
                style: theme.captionStyle.copyWith(color: theme.textSecondary),
              ),
              const SizedBox(height: 4),
              ...expense.paidBy.map((payer) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _avatar(payer.userId, theme.positive, theme),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _displayName(payer.userId),
                            style: theme.bodyStyle
                                .copyWith(color: theme.textPrimary),
                          ),
                        ),
                        Text(
                          formatCurrency(payer.amount, expense.currency),
                          style: theme.amountStyle
                              .copyWith(color: theme.positive),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 12),

              // Split breakdown
              Row(
                children: [
                  Text(
                    'Split (${expense.mode.name})',
                    style:
                        theme.captionStyle.copyWith(color: theme.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${expense.splitAmong.length} people',
                    style:
                        theme.captionStyle.copyWith(color: theme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...expense.splitAmong.map((uid) {
                final share = perMemberShare[uid] ?? 0.0;
                final isPayer = expense.paidBy.any((p) => p.userId == uid);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _avatar(uid, theme.negative, theme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _displayName(uid),
                          style: theme.bodyStyle
                              .copyWith(color: theme.textPrimary),
                        ),
                      ),
                      Text(
                        formatCurrency(share, expense.currency),
                        style: theme.amountStyle.copyWith(
                          color: isPayer ? theme.neutral : theme.negative,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Splitwise-style settlement view with "you" perspective
  // ---------------------------------------------------------------------------

  Widget _buildSettlementView(BuildContext ctx, Settlement settlement) {
    final theme = XpenslyTheme.of(ctx);
    final debts = settlement.simplified.isNotEmpty
        ? settlement.simplified
        : settlement.deltas;
    final maxBalance = settlement.entries.isEmpty
        ? 0.0
        : settlement.entries
            .map((e) => e.netBalance.abs())
            .reduce((a, b) => a > b ? a : b);

    // Find current user's entry.
    final myEntry = settlement.entries.firstWhere(
      (e) => e.userId == _currentUserId,
      orElse: () => settlement.entries.first,
    );
    final myBalance = myEntry.netBalance;
    final myBalanceLabel = myBalance.abs() < 0.01
        ? 'You are all settled up'
        : myBalance > 0
            ? 'You are owed ${formatCurrency(myBalance.abs(), 'USD')}'
            : 'You owe ${formatCurrency(myBalance.abs(), 'USD')} overall';
    final myBalanceColor = myBalance.abs() < 0.01
        ? theme.neutral
        : myBalance > 0
            ? theme.positive
            : theme.negative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Your summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.cardRadius,
          ),
          child: Column(
            children: [
              Text(
                myBalanceLabel,
                style: theme.titleStyle.copyWith(color: myBalanceColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Total trip: ${formatCurrency(settlement.totalSpent, 'USD')}  \u2022  '
                '${formatCurrency(settlement.perPerson, 'USD')}/person',
                style: theme.captionStyle.copyWith(color: theme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Per-member balances
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.cardRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group balances',
                style: theme.titleStyle.copyWith(color: theme.textPrimary),
              ),
              const SizedBox(height: 12),
              ...settlement.entries.map((entry) {
                final isMe = entry.userId == _currentUserId;
                final isPositive = entry.netBalance > 0;
                final isZero = entry.netBalance.abs() < 0.01;
                final statusColor = isZero
                    ? theme.neutral
                    : isPositive
                        ? theme.positive
                        : theme.negative;

                String statusText;
                if (isZero) {
                  statusText = 'settled up';
                } else if (isMe) {
                  statusText = isPositive
                      ? 'you get back ${formatCurrency(entry.netBalance.abs(), 'USD')}'
                      : 'you owe ${formatCurrency(entry.netBalance.abs(), 'USD')}';
                } else {
                  statusText = isPositive
                      ? 'gets back ${formatCurrency(entry.netBalance.abs(), 'USD')}'
                      : 'owes ${formatCurrency(entry.netBalance.abs(), 'USD')}';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: isMe
                      ? BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Row(
                    children: [
                      _avatar(
                        entry.userId,
                        statusColor,
                        theme,
                        showBorder: isMe,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? '${entry.name} (you)' : entry.name,
                              style: theme.bodyStyle
                                  .copyWith(color: theme.textPrimary),
                            ),
                            Text(
                              statusText,
                              style:
                                  theme.captionStyle.copyWith(color: statusColor),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: isZero
                            ? const SizedBox.shrink()
                            : FractionallySizedBox(
                                alignment: isPositive
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                widthFactor:
                                    (entry.netBalance.abs() / maxBalance)
                                        .clamp(0.08, 1.0),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Settle up section — who pays whom (with "you" perspective)
        if (debts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Settle up',
              style: theme.titleStyle.copyWith(color: theme.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              settlement.simplified.isNotEmpty
                  ? 'Simplified from ${settlement.deltas.length} to ${settlement.simplified.length} payments'
                  : '${debts.length} payment${debts.length == 1 ? '' : 's'} needed',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
          ),
          const SizedBox(height: 8),

          // Separate: debts involving "you" first
          ..._sortedDebts(debts).map((delta) {
            final isFromMe = delta.from == _currentUserId;
            final isToMe = delta.to == _currentUserId;
            final fromLabel =
                isFromMe ? 'You' : (_nameMap[delta.from] ?? delta.from);
            final toLabel =
                isToMe ? 'you' : (_nameMap[delta.to] ?? delta.to);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: theme.cardRadius,
                border: (isFromMe || isToMe)
                    ? Border.all(
                        color: theme.primary.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _avatar(delta.from, theme.negative, theme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: theme.bodyStyle
                                .copyWith(color: theme.textPrimary),
                            children: [
                              TextSpan(text: fromLabel),
                              TextSpan(
                                text: isFromMe ? ' owe ' : ' owes ',
                                style:
                                    TextStyle(color: theme.textSecondary),
                              ),
                              TextSpan(text: toLabel),
                            ],
                          ),
                        ),
                      ),
                      _avatar(delta.to, theme.positive, theme),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrency(delta.amount, delta.currency),
                    style: theme.amountStyle.copyWith(
                      color: isFromMe ? theme.negative : theme.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Payment buttons
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ..._xpensly.paymentProviders.map((provider) {
                        return GestureDetector(
                          onTap: () =>
                              _showSettleUpDialog(ctx, delta, provider.name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      theme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Pay via ${provider.name}',
                              style: theme.captionStyle
                                  .copyWith(color: theme.primary),
                            ),
                          ),
                        );
                      }),
                      // Cash option
                      GestureDetector(
                        onTap: () =>
                            _showSettleUpDialog(ctx, delta, 'cash'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.neutral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: theme.neutral.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Cash',
                            style: theme.captionStyle
                                .copyWith(color: theme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ] else
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: theme.positive),
                const SizedBox(height: 8),
                Text(
                  'All settled up!',
                  style: theme.titleStyle.copyWith(color: theme.positive),
                ),
              ],
            ),
          ),

        // Category breakdown
        if (settlement.byCategory.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: theme.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending by category',
                  style: theme.titleStyle.copyWith(color: theme.textPrimary),
                ),
                const SizedBox(height: 8),
                ..._sortedMap(settlement.byCategory).map((e) {
                  final pct = settlement.totalSpent > 0
                      ? e.value / settlement.totalSpent
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: theme.bodyStyle
                                    .copyWith(color: theme.textPrimary)),
                            Text(
                              '${formatCurrency(e.value, 'USD')} (${(pct * 100).toStringAsFixed(0)}%)',
                              style: theme.captionStyle
                                  .copyWith(color: theme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                                theme.neutral.withValues(alpha: 0.2),
                            color: theme.primary.withValues(alpha: 0.7),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _displayName(String userId) {
    if (userId == _currentUserId) return '${_nameMap[userId] ?? userId} (you)';
    return _nameMap[userId] ?? userId;
  }

  Widget _avatar(String userId, Color accentColor, XpenslyThemeData theme,
      {bool showBorder = false}) {
    final name = _nameMap[userId] ?? userId;
    final isMe = userId == _currentUserId;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.15),
        border: (showBorder || isMe)
            ? Border.all(color: theme.primary, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        name[0].toUpperCase(),
        style: theme.captionStyle.copyWith(color: accentColor, fontSize: 13),
      ),
    );
  }

  /// Sort debts: "your" debts first, then by amount descending.
  List<DebtDelta> _sortedDebts(List<DebtDelta> debts) {
    final sorted = List<DebtDelta>.from(debts);
    sorted.sort((a, b) {
      final aInvolvesMe =
          a.from == _currentUserId || a.to == _currentUserId ? 0 : 1;
      final bInvolvesMe =
          b.from == _currentUserId || b.to == _currentUserId ? 0 : 1;
      if (aInvolvesMe != bInvolvesMe) return aInvolvesMe - bInvolvesMe;
      return b.amount.compareTo(a.amount);
    });
    return sorted;
  }

  List<MapEntry<String, double>> _sortedMap(Map<String, double> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = XpenslyTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bali Adventure 2026',
              style: theme.titleStyle.copyWith(color: theme.textPrimary),
            ),
            Text(
              '4 members  \u2022  Mar 15\u201322',
              style: theme.captionStyle.copyWith(color: theme.textSecondary),
            ),
          ],
        ),
        actions: [
          // User perspective picker
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primary.withValues(alpha: 0.2),
                    border: Border.all(color: theme.primary, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _currentUserName()[0],
                    style: theme.captionStyle
                        .copyWith(color: theme.primary, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, color: theme.primary, size: 16),
              ],
            ),
            color: theme.surface,
            onSelected: (uid) => setState(() {
              _currentUserId = uid;
              _dashboardKey++;
            }),
            itemBuilder: (_) => _members
                .map((m) => PopupMenuItem(
                      value: m.id,
                      child: Row(
                        children: [
                          if (m.id == _currentUserId)
                            Icon(Icons.check, size: 16, color: theme.primary)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(
                            m.name,
                            style: theme.bodyStyle
                                .copyWith(color: theme.textPrimary),
                          ),
                          if (m.id == _currentUserId) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(you)',
                              style: theme.captionStyle
                                  .copyWith(color: theme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ))
                .toList(),
          ),
          // Theme switcher
          PopupMenuButton<String>(
            icon: Icon(Icons.palette_outlined, color: theme.primary),
            color: theme.surface,
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => [
              _themeItem('hello', 'Hello (Dark)', widget.currentTheme),
              _themeItem('material', 'Material 3', widget.currentTheme),
              _themeItem('minimal', 'Minimal', widget.currentTheme),
            ],
          ),
        ],
      ),
      body: _loading || _tripId == null
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : XpenslyDashboard(
              key: ValueKey(_dashboardKey),
              xpensly: _xpensly,
              tripId: _tripId!,
              settlementBuilder: _buildSettlementView,
              onExpenseTap: (expense) => _showExpenseDetail(context, expense),
            ),
    );
  }

  PopupMenuItem<String> _themeItem(
      String value, String label, String current) {
    final theme = XpenslyTheme.of(context);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == current)
            Icon(Icons.check, size: 16, color: theme.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label,
              style: theme.bodyStyle.copyWith(color: theme.textPrimary)),
        ],
      ),
    );
  }
}
