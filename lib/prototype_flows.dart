part of 'main.dart';

class Beneficiary {
  Beneficiary(this.name, this.account, this.bank, this.asset);
  final String name, account, bank, asset;
}

class DemoState {
  final login = TextEditingController(), password = TextEditingController();
  final otp = List.generate(6, (_) => TextEditingController());
  final otpFocus = List.generate(6, (_) => FocusNode());
  final search = TextEditingController(),
      beneficiaryName = TextEditingController();
  final beneficiaryAccount = TextEditingController(),
      nickname = TextEditingController();
  final goalName = TextEditingController(text: 'New Laptop'),
      goalAmount = TextEditingController(text: '100,000');
  final chat = TextEditingController();
  final beneficiaries = [
    Beneficiary('John Wick', '7755', 'FinTrust', 'assets/local/252_346.png'),
    Beneficiary('Nick Fury', '6611', 'FinTrust', 'assets/local/254_353.png'),
    Beneficiary('Abishek', '3840', 'BOC', 'assets/local/253_352.png'),
    Beneficiary('Afil Musthafa', '3646', 'Sampath', 'assets/local/253_349.png'),
    Beneficiary(
      'Sajintha Pradeep',
      '5578',
      'FinTrust',
      'assets/local/253_350.png',
    ),
    Beneficiary('Sulokshan', '5442', 'HNB', 'assets/local/253_351.png'),
  ];
  late Beneficiary selected = beneficiaries.first;
  String bank = 'FinTrust',
      transferType = 'To Other Bank',
      historyFilter = 'All',
      notificationFilter = 'All';
  String language = 'English', chatReply = '', accountName = 'Saving Account';
  String? createdGoal;
  double createdGoalAmount = 0;
  DateTime? goalDate;
  bool showPassword = false, biometric = false, notificationsCleared = false;
  void dispose() {
    for (final c in [
      login,
      password,
      ...otp,
      search,
      beneficiaryName,
      beneficiaryAccount,
      nickname,
      goalName,
      goalAmount,
      chat,
    ]) {
      c.dispose();
    }
    for (final f in otpFocus) {
      f.dispose();
    }
  }
}

extension _PrototypeFlows on _BankingPrototypeState {
  List<Widget> prototypeLinks() {
    final links = (scenes![screen]['links'] as List?) ?? [];
    return [
      for (final l in links)
        if (scenes!.containsKey(l['target']))
          hit(
            'Open ${scenes![l['target']]['name']}',
            (l['x'] as num).toDouble(),
            (l['y'] as num).toDouble(),
            (l['w'] as num).toDouble(),
            (l['h'] as num).toDouble(),
            () => go(l['target'] as String),
          ),
    ];
  }

  bool flowReplaced(Map<String, dynamic> l) {
    final id = l['id'];
    final inputs = <String, List<String>>{
      '211:995': ['272:352', '272:353'],
      '211:1349': ['211:1386'],
      '211:1472': ['211:1482'],
      '211:1536': ['211:1540'],
      '211:1564': ['211:1570', '211:1571', '211:1572', '211:1573'],
      '211:761': ['234:607', '234:608'],
      '211:846': ['211:861'],
    };
    if (inputs[screen]?.contains(id) == true) return true;
    if (screen == '211:1536' && demo.search.text.isNotEmpty) {
      final y = (l['y'] as num).toDouble() + (l['h'] as num) / 2;
      for (var i = 0; i < 6; i++) {
        if (y >= 215 + i * 88 && y < 295 + i * 88 && !matchesBeneficiary(i)) {
          return true;
        }
      }
    }
    if (screen == '211:1349') {
      final y = (l['y'] as num).toDouble() + (l['h'] as num) / 2;
      for (var i = 0; i < 7; i++) {
        if (y >= historyY[i] - 9 &&
            y < historyY[i] + 59 &&
            !matchesTransaction(i)) {
          return true;
        }
      }
    }
    if (screen == '211:813') {
      final y = (l['y'] as num).toDouble() + (l['h'] as num) / 2;
      for (var i = 0; i < 5; i++) {
        if (y >= notificationY[i] - 12 &&
            y < notificationY[i] + 85 &&
            !matchesNotification(i)) {
          return true;
        }
      }
    }
    if (screen == '211:1472' && demo.search.text.isNotEmpty) {
      final y = (l['y'] as num).toDouble() + (l['h'] as num) / 2;
      for (var i = 0; i < 5; i++) {
        if (y >= 333 + i * 80 &&
            y < 391 + i * 80 &&
            !searchItems[i].toLowerCase().contains(
              demo.search.text.toLowerCase(),
            )) {
          return true;
        }
      }
    }
    return false;
  }

  String flowText(Map<String, dynamic> l) {
    final id = l['id'];
    var text = l['text'] as String;
    if (['211:512', '211:538'].contains(screen)) {
      if (['211:516', '211:542'].contains(id)) text = demo.selected.name;
      if (['211:517', '211:548'].contains(id)) {
        text = '********${demo.selected.account}';
      }
      if (id == '211:545') text = demo.transferType;
    }
    if (screen == '211:528' && id == '211:534') {
      text = 'To ${demo.selected.name}';
    }
    if (screen == '211:1250') {
      if (id == '211:1252') text = demo.accountName;
      // Keep the account balance in the clean LKR format without the old
      // Sri Lankan "/=" suffix from the original design.
      if (id == '211:1254') text = 'LKR ${money(balance)}';
    }
    if (screen == '211:1159' && id == '211:1162') {
      text = 'LKR ${money(balance)}';
    }
    if (screen == '211:761' && id == '234:609' && demo.goalDate != null) {
      text =
          '${demo.goalDate!.day}/${demo.goalDate!.month}/${demo.goalDate!.year}';
    }
    if (screen == '211:740' && demo.createdGoal != null) {
      if (id == '234:591') text = demo.createdGoal!;
      if (id == '234:590') {
        text =
            'LKR 0 / ${money(demo.createdGoalAmount).replaceFirst('.00', '')}';
      }
      if (id == '234:592') text = '0%';
    }
    if (screen == '211:872' && id == '211:896') text = demo.language;
    // Keep masks compact and separate the visible last four digits.
    return text.replaceAllMapped(RegExp(r'\*{2,}(\d+)'), (match) {
      final digits = match.group(1)!;
      final lastFour = digits.length > 4
          ? digits.substring(digits.length - 4)
          : digits;
      return '•••• $lastFour';
    });
  }

  bool matchesBeneficiary(int i) =>
      '${demo.beneficiaries[i].name} ${demo.beneficiaries[i].bank} ${demo.beneficiaries[i].account}'
          .toLowerCase()
          .contains(demo.search.text.toLowerCase());
  List<double> get historyY => [304, 389, 471, 558, 694, 770, 846];
  List<String> get transactionNames => [
    'Food City',
    'Salary',
    'Airtel',
    'Bank Transfer',
    'Electricity Bill',
    'ATM withdrawal',
    'Grocery Mart',
  ];
  bool matchesTransaction(int i) =>
      transactionNames[i].toLowerCase().contains(
        demo.search.text.toLowerCase(),
      ) &&
      (demo.historyFilter == 'All' ||
          (demo.historyFilter == 'Income' && i == 1) ||
          (demo.historyFilter == 'Expenses' && i != 1 && i != 3) ||
          (demo.historyFilter == 'Transfers' && i == 3));
  List<double> get notificationY => [195, 315, 430, 545, 660];
  bool matchesNotification(int i) =>
      !demo.notificationsCleared &&
      (demo.notificationFilter == 'All' ||
          (demo.notificationFilter == 'Transactions' && i < 3) ||
          (demo.notificationFilter == 'Security' && i == 3) ||
          (demo.notificationFilter == 'Offers' && i == 4));
  List<String> get searchItems => [
    'Food City',
    'Airtel',
    'University Fees',
    'Transfer To Mike',
    'Colombo Branch',
  ];

  Widget entry(
    String label,
    TextEditingController controller,
    double x,
    double y,
    double w,
    double h, {
    String? hint,
    bool secret = false,
    bool digits = false,
    TextAlign align = TextAlign.start,
    FocusNode? focus,
    ValueChanged<String>? changed,
    int? maxLength,
    double fontSize = 20,
  }) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: Semantics(
      label: label,
      child: TextField(
        controller: controller,
        focusNode: focus,
        obscureText: secret,
        textAlign: align,
        maxLength: maxLength,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        autocorrect: !secret,
        inputFormatters: digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          fontVariations: [
            FontVariation('wght', 400),
            FontVariation('opsz', fontSize),
          ],
          height: 1.21,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
          hintText: hint,
          hintStyle: TextStyle(
            color: const Color(0xff757575),
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            fontVariations: [
              FontVariation('wght', 300),
              FontVariation('opsz', fontSize),
            ],
          ),
        ),
        onChanged: (v) {
          update(() {});
          changed?.call(v);
        },
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    ),
  );

  Future<void> info(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SelectableText(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Future<String?> choose(String title, List<String> options) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final option in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(option),
                ),
              ),
          ],
        ),
      );
  void loginDemo() {
    if (demo.login.text.trim().isEmpty || demo.password.text.isEmpty) {
      message(
        'Enter an email or mobile number and a password to try the demo.',
      );
      return;
    }
    for (final c in demo.otp) {
      c.clear();
    }
    go('211:1013');
    message('Demo verification code: 123456. No SMS is sent.');
  }

  void verifyDemo() {
    if (demo.otp.map((c) => c.text).join() != '123456') {
      message('Enter the six-digit demo code: 123456.');
      return;
    }
    demo.password.clear();
    go('211:1029');
  }

  void selectBeneficiary(Beneficiary item) {
    update(() => demo.selected = item);
    go('211:512');
  }

  void saveBeneficiary() {
    if (demo.beneficiaryName.text.trim().isEmpty ||
        !RegExp(r'^\d{4,20}$').hasMatch(demo.beneficiaryAccount.text)) {
      message('Enter a name and an account number with 4–20 digits.');
      return;
    }
    final b = Beneficiary(
      demo.beneficiaryName.text.trim(),
      demo.beneficiaryAccount.text,
      demo.bank,
      '',
    );
    demo.beneficiaries.add(b);
    selectBeneficiary(b);
    message('Beneficiary saved for this demo session.');
  }

  Future<void> pickGoalDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: demo.goalDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null && mounted) update(() => demo.goalDate = date);
  }

  void createGoal() {
    final value = double.tryParse(demo.goalAmount.text.replaceAll(',', ''));
    if (demo.goalName.text.trim().isEmpty ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        demo.goalDate == null) {
      message('Enter a goal name, positive target amount, and target date.');
      return;
    }
    update(() {
      demo.createdGoal = demo.goalName.text.trim();
      demo.createdGoalAmount = value;
    });
    go('211:740');
  }

  void reply([String? prompt]) {
    final question = (prompt ?? demo.chat.text).trim();
    if (question.isEmpty) return;
    final q = question.toLowerCase();
    String answer;
    if (q.contains('balance')) {
      answer = 'Your demo available balance is LKR ${money(balance)}.';
    } else if (q.contains('lost') || q.contains('freeze')) {
      answer = 'Open Cards → Card Controls to freeze your demo card. For a real lost card, contact your bank.';
    } else if (q.contains('transaction')) {
      answer = 'Your sample Food City purchase was LKR 3,450 on 01 Oct 2026 at 13:45. Reference FT2456821.';
    } else if (q.contains('atm')) {
      answer = 'This offline demo has no live ATM locations. Contact your bank for its current branch and ATM directory.';
    } else if (q.contains('agent')) {
      answer = 'Live support is not connected in this local demo.';
    } else {
      answer = 'I can explain your sample balance, recent transaction, or card controls. These are offline demo responses.';
    }
    update(() {
      demo.chatReply = answer;
      demo.chat.clear();
    });
  }

  Future<void> billForm(String category) async {
    final account = TextEditingController(), value = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: account,
              decoration: const InputDecoration(
                labelText: 'Bill account number',
              ),
            ),
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount in LKR'),
            ),
            const SizedBox(height: 12),
            const Text('Demo only. No real bill payment will be made.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(value.text);
              if (account.text.trim().isEmpty ||
                  amount == null ||
                  !amount.isFinite ||
                  amount <= 0) {
                message('Enter a bill account number and a positive amount.');
                return;
              }
              Navigator.pop(context);
              message(
                'Demo $category payment of LKR ${money(amount)} recorded.',
              );
            },
            child: const Text('Confirm demo payment'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    account.dispose();
    value.dispose();
  }

  List<Widget> flowControls() {
    final result = <Widget>[];
    if (['211:1159', '211:1250'].contains(screen)) {
      for (final item in [
        (20.0, 'Home', '211:1046'),
        (100.0, 'Accounts', '211:1159'),
        (190.0, 'Search', '211:1472'),
        (270.0, 'Cards', '211:632'),
        (350.0, 'Profile', '211:872'),
      ]) {
        result.add(hit(item.$2, item.$1, 883, 75, 65, () => go(item.$3)));
      }
    }
    if (['211:512', '211:538'].contains(screen) &&
        demo.selected.name != 'John Wick') {
      result.add(
        Positioned(
          left: 36,
          top: 171,
          width: 100,
          height: 100,
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: demo.selected.asset.isNotEmpty
                  ? Image.asset(demo.selected.asset, width: 94, height: 94)
                  : CircleAvatar(
                      radius: 35,
                      backgroundColor: const Color(0xffe8f0fe),
                      child: Text(
                        demo.selected.name.substring(0, 1),
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    switch (screen) {
      case '211:966':
        result.addAll([
          hit('Skip onboarding', 40, 845, 80, 56, () => go('211:982')),
          hit('Next onboarding screen', 337, 842, 65, 65, () => go('211:982')),
        ]);
      case '211:982':
        result.add(hit('Get started', 20, 840, 400, 60, () => go('211:995')));
      case '211:995':
        result.addAll([
          entry(
            'Email or mobile number',
            demo.login,
            39,
            280,
            350,
            32,
            hint: 'Enter Email or Mobile Number',
          ),
          entry(
            'Password',
            demo.password,
            39,
            364,
            330,
            32,
            hint: 'Enter Password',
            secret: !demo.showPassword,
          ),
          hit(
            'Show password',
            375,
            352,
            40,
            48,
            () => update(() => demo.showPassword = !demo.showPassword),
          ),
          hit('Log in', 22, 482, 400, 55, loginDemo),
          hit(
            'Forgot password',
            235,
            417,
            185,
            42,
            () => info(
              'Password reset',
              'This prototype uses local demo sign-in. No real account or password is stored. Enter any email or mobile number and password, then use code 123456.',
            ),
          ),
        ]);
      case '211:1013':
        for (var i = 0; i < 6; i++) {
          final index = i;
          result.add(
            entry(
              'Verification digit ${i + 1}',
              demo.otp[i],
              60 + i * 54,
              332,
              50,
              40,
              digits: true,
              align: TextAlign.center,
              focus: demo.otpFocus[i],
              maxLength: 1,
              fontSize: 28,
              changed: (v) {
                if (v.isNotEmpty && index < 5) {
                  demo.otpFocus[index + 1].requestFocus();
                }
              },
            ),
          );
        }
        result.addAll([
          hit('Verify code', 22, 663, 400, 55, verifyDemo),
          hit(
            'Resend code',
            110,
            410,
            240,
            48,
            () => message('Demo verification code: 123456. No SMS is sent.'),
          ),
        ]);
      case '211:1029':
        result.addAll([
          hit('Enable biometric demo', 20, 675, 400, 55, () {
            demo.biometric = true;
            go('211:1046');
            message(
              'Biometric preference enabled for the demo; device authentication is not connected.',
            );
          }),
          hit('Maybe later', 20, 770, 400, 55, () => go('211:1046')),
        ]);
      case '211:1159':
        for (var i = 0; i < 4; i++) {
          final name = [
            'Saving Account',
            'Current Account',
            'Fixed Deposit',
            'Investment Account',
          ][i];
          result.add(
            hit('Open $name', 20, 110 + i * 140, 400, 110, () {
              demo.accountName = name;
              go('211:1250');
            }),
          );
        }
        result.add(
          hit(
            'Add account',
            370,
            45,
            55,
            55,
            () => info(
              'Add account',
              'Account opening requires a banking service. This prototype contains four sample accounts.',
            ),
          ),
        );
      case '211:1250':
        result.addAll([
          hit('Transactions', 20, 260, 85, 115, () => go('211:1349')),
          hit(
            'Statement',
            128,
            260,
            80,
            115,
            () => info(
              'Account statement',
              'Demo statement — October 2026\nFood City: −LKR 3,450\nSalary: +LKR 80,000\nAvailable: LKR ${money(balance)}',
            ),
          ),
          hit('Manage account', 232, 260, 80, 115, () => go('211:1510')),
          hit('More account options', 336, 260, 80, 115, () => go('211:632')),
          hit('Food City transaction', 20, 725, 400, 55, () => go('211:1442')),
        ]);
      case '211:1510':
        for (final row in [
          (170.0, 'FinTrust account'),
          (270.0, 'Other bank'),
          (370.0, 'Mobile wallet'),
          (470.0, 'International transfer'),
        ]) {
          result.add(
            hit(row.$2, 20, row.$1, 400, 70, () {
              demo.transferType = 'To ${row.$2}';
              go('211:1536');
            }),
          );
        }
        result.addAll([
          hit('QR code transfer', 20, 574, 400, 70, () => go('211:556')),
          hit('Beneficiaries', 20, 675, 400, 70, () => go('211:1536')),
        ]);
      case '211:1536':
        result.add(
          entry(
            'Search beneficiaries',
            demo.search,
            95,
            145,
            310,
            34,
            hint: 'Search Anything / Ask Ai',
          ),
        );
        for (var i = 0; i < 6; i++) {
          final b = demo.beneficiaries[i];
          if (matchesBeneficiary(i)) {
            result.add(
              hit(
                'Select ${b.name}',
                20,
                215 + i * 88,
                400,
                78,
                () => selectBeneficiary(b),
              ),
            );
          }
        }
        result.add(
          hit('Add new beneficiary', 20, 825, 400, 55, () => go('211:1564')),
        );
        if (demo.beneficiaries.length > 6) {
          result.add(
            const Positioned(
              left: 30,
              top: 765,
              child: Text(
                'View saved beneficiaries',
                style: TextStyle(fontSize: 16, color: Color(0xff0055ff)),
              ),
            ),
          );
          result.add(
            hit('Saved beneficiaries', 20, 750, 400, 50, () async {
              final picked = await choose(
                'Saved beneficiaries',
                demo.beneficiaries.skip(6).map((b) => b.name).toList(),
              );
              if (picked != null) {
                selectBeneficiary(
                  demo.beneficiaries.firstWhere((b) => b.name == picked),
                );
              }
            }),
          );
        }
      case '211:1564':
        result.addAll([
          entry(
            'Beneficiary full name',
            demo.beneficiaryName,
            47,
            247,
            350,
            32,
            hint: 'Full Name',
          ),
          entry(
            'Beneficiary account number',
            demo.beneficiaryAccount,
            47,
            437,
            350,
            32,
            hint: 'Account Number',
            digits: true,
          ),
          entry(
            'Beneficiary nickname',
            demo.nickname,
            47,
            530,
            350,
            32,
            hint: 'Nickname (Optional)',
          ),
          Positioned(
            left: 47,
            top: 341,
            child: Text(demo.bank, style: const TextStyle(fontSize: 20)),
          ),
          hit('Select bank', 20, 325, 400, 55, () async {
            final bank = await choose('Select Bank', [
              'FinTrust',
              'BOC',
              'Sampath',
              'HNB',
            ]);
            if (bank != null && mounted) update(() => demo.bank = bank);
          }),
          hit(
            'Local bank',
            20,
            130,
            200,
            55,
            () => update(() => demo.bank = 'BOC'),
          ),
          hit(
            'FinTrust bank',
            220,
            130,
            200,
            55,
            () => update(() => demo.bank = 'FinTrust'),
          ),
          hit('Save beneficiary', 20, 824, 400, 55, saveBeneficiary),
        ]);
      case '211:632':
        result.addAll([
          hit('Card controls', 20, 346, 400, 70, () => go('211:651')),
          hit('Saving goals', 20, 452, 400, 70, () => go('211:740')),
          hit('Card settings', 20, 558, 400, 70, () => go('211:651')),
          hit(
            'Request new card',
            20,
            664,
            400,
            70,
            () => info(
              'Request new card',
              'Your demo card request is ready. A real request requires connecting the bank’s card service.',
            ),
          ),
        ]);
      case '211:740':
        result.addAll([
          hit('Create saving goal', 370, 45, 55, 55, () => go('211:761')),
          hit(
            'View saving plan',
            20,
            776,
            190,
            80,
            () => info(
              'Savings plan',
              'Laptop Fund: LKR 72,000 of 100,000\nTravel Fund: LKR 19,000 of 70,000${demo.createdGoal == null ? '' : '\n${demo.createdGoal}: LKR 0 of ${money(demo.createdGoalAmount)}'}',
            ),
          ),
          hit('Report lost card', 228, 776, 190, 80, () => go('211:651')),
        ]);
        if (demo.createdGoal != null) {
          result.add(
            Positioned(
              left: 40,
              top: 630,
              width: 350,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        }
      case '211:761':
        result.addAll([
          entry('Goal name', demo.goalName, 54, 387, 330, 35),
          entry('Goal target amount', demo.goalAmount, 54, 530, 330, 35),
          hit('Target date', 20, 640, 400, 80, pickGoalDate),
          hit('Create goal', 20, 800, 400, 80, createGoal),
        ]);
      case '211:1349':
        result.add(
          entry(
            'Search transactions',
            demo.search,
            93,
            144,
            310,
            35,
            hint: 'Search Anything/ Ask Ai',
          ),
        );
        for (var i = 0; i < 4; i++) {
          final filter = ['All', 'Income', 'Expenses', 'Transfers'][i];
          final x = [20.0, 95.0, 200.0, 315.0][i];
          if (demo.historyFilter == filter && filter != 'All') {
            result.add(selection(x, 210, 100, 40));
          }
          result.add(
            hit(
              'Filter $filter',
              x,
              210,
              100,
              40,
              () => update(() => demo.historyFilter = filter),
            ),
          );
        }
        for (var i = 0; i < 7; i++) {
          final index = i;
          if (matchesTransaction(i)) {
            result.add(
              hit(
                'View ${transactionNames[i]}',
                20,
                historyY[i] - 5,
                400,
                65,
                () => index == 0
                    ? go('211:1442')
                    : info(
                        transactionNames[index],
                        'Sample transaction from your prototype. For the complete designed receipt, open the Food City transaction.',
                      ),
              ),
            );
          }
        }
      case '211:1442':
        result.add(
          hit(
            'Download receipt',
            20,
            820,
            400,
            55,
            () => info(
              'Transaction receipt',
              'Food City-Colombo\nLKR 3,450.00\n01 Oct 2026 13:45\nCard Payment\nReference: FT2456821\nSavings •••• 4502\nStatus: Success\n\nDemo receipt — no real transaction.',
            ),
          ),
        );
      case '211:1472':
        result.add(
          entry(
            'Search app',
            demo.search,
            95,
            141,
            310,
            35,
            hint: 'Search Anything/ Ask Ai',
          ),
        );
        for (var i = 0; i < 5; i++) {
          final index = i;
          if (searchItems[i].toLowerCase().contains(
            demo.search.text.toLowerCase(),
          )) {
            result.add(
              hit(
                searchItems[i],
                20,
                337 + i * 80,
                400,
                55,
                () => [0, 1, 2, 3].contains(index)
                    ? go(['211:1442', '211:601', '211:570', '211:1536'][index])
                    : info(
                        'Colombo Branch',
                        'This demo does not connect to a live branch directory.',
                      ),
              ),
            );
          }
        }
        result.addAll([
          hit('AI assistant', 232, 791, 80, 105, () => go('211:846')),
          hit('Services', 336, 791, 80, 105, () => go('211:570')),
          hit(
            'Branches',
            24,
            791,
            80,
            105,
            () => info(
              'Branches',
              'Live branch search is not connected in this demo.',
            ),
          ),
          hit(
            'ATMs',
            128,
            791,
            80,
            105,
            () => info(
              'ATMs',
              'Live ATM locations are not connected in this offline demo.',
            ),
          ),
          hit('Search transactions', 121, 220, 139, 40, () => go('211:1349')),
          hit('Search beneficiaries', 291, 220, 126, 40, () => go('211:1536')),
        ]);
      case '211:813':
        for (final tab in [
          (20.0, 70.0, 'All'),
          (93.0, 140.0, 'Transactions'),
          (240.0, 80.0, 'Offers'),
          (329.0, 91.0, 'Security'),
        ]) {
          if (demo.notificationFilter == tab.$3 && tab.$3 != 'All') {
            result.add(selection(tab.$1, 113, tab.$2, 40));
          }
          result.add(
            hit(
              'Notifications ${tab.$3}',
              tab.$1,
              113,
              tab.$2,
              40,
              () => update(() => demo.notificationFilter = tab.$3),
            ),
          );
        }
        result.addAll([
          hit(
            'Clear all notifications',
            160,
            806,
            120,
            50,
            () => update(() => demo.notificationsCleared = true),
          ),
          hit('Financial insights', 380, 43, 45, 45, () => go('211:795')),
        ]);
      case '211:846':
        result.add(
          entry(
            'Ask assistant',
            demo.chat,
            50,
            870,
            290,
            35,
            hint: 'Ask me anything...',
          ),
        );
        result.add(hit('Send message', 352, 855, 52, 52, reply));
        for (final item in [
          (525.0, 'Check Balance'),
          (590.0, 'Find nearest ATM'),
          (655.0, 'Report Lost Card'),
          (720.0, 'Explain recent Transaction'),
          (785.0, 'Talk to Live Agent'),
        ]) {
          result.add(hit(item.$2, 146, item.$1, 274, 50, () => reply(item.$2)));
        }
        if (demo.chatReply.isNotEmpty) {
          result.add(
            Positioned(
              left: 30,
              top: 355,
              width: 380,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f0fe),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  demo.chatReply,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        }
      case '211:872':
        result.addAll([
          hit(
            'Personal information',
            20,
            380,
            400,
            70,
            () => info(
              'Personal information',
              'Rizha RM\nrizha@gmail.com\n\nThis is the sample profile in your design.',
            ),
          ),
          hit(
            'Privacy and settings',
            20,
            473,
            400,
            70,
            () => info(
              'Privacy & Settings',
              'This local demo stores input only in memory. It has no banking server, analytics, or real authentication.',
            ),
          ),
          hit('Language', 20, 566, 400, 70, () async {
            final lang = await choose('Language', [
              'English',
              'සිංහල',
              'தமிழ்',
            ]);
            if (lang != null && mounted) update(() => demo.language = lang);
          }),
          hit('Manage biometric', 20, 659, 400, 70, () => go('211:1029')),
          hit('Log out', 20, 752, 400, 70, () {
            history.clear();
            demo.password.clear();
            go('211:995');
            history.clear();
          }),
        ]);
    }
    return result;
  }
}
