import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'prototype_flows.dart';

void main() => runApp(const FinTrustApp());

class FinTrustApp extends StatelessWidget {
  const FinTrustApp({super.key, this.initialScreen = '211:945'});
  final String initialScreen;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FinTrust',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1e6bff)),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    ),
    home: BankingPrototype(initialScreen: initialScreen),
  );
}

/// Individual native widgets reproduce the captured 440 × 956 Figma frames.
/// No screenshot is used as an application screen.
class BankingPrototype extends StatefulWidget {
  const BankingPrototype({super.key, required this.initialScreen});
  final String initialScreen;
  @override
  State<BankingPrototype> createState() => _BankingPrototypeState();
}

class _BankingPrototypeState extends State<BankingPrototype> {
  Map<String, dynamic>? scenes;
  String? loadError;
  final demo = DemoState();
  void update(VoidCallback change) => setState(change);
  late String screen = widget.initialScreen;
  final history = <String>[];
  Timer? splashTimer;
  final amount = TextEditingController(text: '10,000');
  final note = TextEditingController(text: 'Rent Payment');
  final phone = TextEditingController();
  final scroll = ScrollController();
  bool scheduled = true, hideBalance = false, transferConfirmed = false;
  final cardControls = [false, true, true, true];
  int? operatorIndex, reloadAmount;
  double balance = 245850;
  static const blue = Color(0xff1e6bff);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = jsonDecode(
        await rootBundle.loadString('assets/design.json'),
      );
      if (!mounted) return;
      setState(() => scenes = data as Map<String, dynamic>);
      if (screen == '211:945') {
        splashTimer = Timer(const Duration(seconds: 3), () => go('211:950'));
      }
    } catch (error) {
      if (mounted) {
        setState(() => loadError = 'Unable to load the app design: $error');
      }
    }
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    demo.dispose();
    amount.dispose();
    note.dispose();
    phone.dispose();
    scroll.dispose();
    super.dispose();
  }

  void go(String target) {
    if (scenes?[target] == null) {
      unavailable('This screen');
      return;
    }
    splashTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      history.add(screen);
      screen = target;
      demo.search.clear();
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(
      () => screen = history.isEmpty ? '211:1046' : history.removeLast(),
    );
  }

  void message(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> unavailable(String title) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const Text('This screen is not included in the demo yet.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  String money(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return '${parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}.${parts[1]}';
  }

  double get transferAmount =>
      double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
  void reviewTransfer() {
    if (!transferAmount.isFinite || transferAmount <= 0) {
      message('Enter an amount greater than zero.');
    } else if (transferAmount + 3 > balance) {
      message('The amount and LKR 3.00 fee exceed the available balance.');
    } else {
      transferConfirmed = false;
      go('211:538');
    }
  }

  void confirmTransfer() {
    if (transferConfirmed) return;
    setState(() {
      transferConfirmed = true;
      balance -= transferAmount + 3;
    });
    go('211:528');
  }

  Future<void> receipt() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Transfer receipt'),
      content: SelectableText(
        'Demo transfer\n\nTo ${demo.selected.name}\n********${demo.selected.account}\nLKR ${money(transferAmount)}\nFee: LKR 3.00\n${note.text}\n03 Oct 2026, 13:45\n\nNo real payment was made.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  Future<void> reloadReview() async {
    if (operatorIndex == null ||
        reloadAmount == null ||
        !RegExp(r'^07\d{8}$').hasMatch(phone.text.replaceAll(' ', ''))) {
      message(
        'Select an operator and amount, and enter a 10-digit mobile number starting with 07.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review mobile reload'),
        content: Text(
          '${['Airtel', 'Hutch', 'Dialog', 'Mobitel'][operatorIndex!]}\n${phone.text}\nLKR $reloadAmount\n\nThis is a local prototype; no reload will be purchased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> customReload() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom amount'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Amount in LKR'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
    if (value != null && mounted) setState(() => reloadAmount = value);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  void screenIndex() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListView(
      children: [
        const ListTile(
          title: Text('FinTrust prototype'),
          subtitle: Text('31 prototype screens · Local demo'),
        ),
        for (final entry in scenes!.entries)
          ListTile(
            title: Text(entry.value['name'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              go(entry.key);
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return Scaffold(body: Center(child: Text(loadError!)));
    }
    if (scenes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final seenText = <String>{};
    final layers = (scenes![screen]['layers'] as List)
        .cast<Map<String, dynamic>>()
        .where((layer) {
          if (layer['type'] != 'text') return true;
          // The source contains exact overlapping copies of navigation labels.
          final signature = jsonEncode([
            layer['text'],
            layer['x'],
            layer['y'],
            layer['w'],
            layer['h'],
            layer['font'],
            layer['fontSize'],
            layer['weight'],
            layer['color'],
            layer['italic'],
          ]);
          return seenText.add(signature);
        })
        .toList();
    return PopScope(
      canPop: history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = math.min(constraints.maxWidth / 440, 1.0);
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 440 * scale,
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: SizedBox(
                      width: 440 * scale,
                      height: 956 * scale,
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.fill,
                        child: GestureDetector(
                          onLongPress: screenIndex,
                          child: SizedBox(
                            key: ValueKey(screen),
                            width: 440,
                            height: 956,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                for (final layer in layers)
                                  if (!_replaced(layer)) _layer(layer),
                                ..._controls(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _replaced(Map<String, dynamic> l) {
    if (flowReplaced(l)) return true;
    final id = l['id'];
    if (screen == '211:512' &&
        ['211:519', '211:522', '211:525', '228:306'].contains(id)) {
      return true;
    }
    if (screen == '211:601' && id == '211:616') return true;
    if (screen == '211:651' &&
        (l['y'] as num) >= 420 &&
        l['type'] != 'text' &&
        (l['x'] as num) > 300) {
      return true;
    }
    return false;
  }

  Color color(String value) => Color(
    int.parse(
      value.replaceFirst('#', value.length == 7 ? 'ff' : ''),
      radix: 16,
    ),
  );
  double numValue(Map<String, dynamic> l, String key) =>
      (l[key] as num).toDouble();
  Widget _layer(Map<String, dynamic> l) {
    if (l['id'] == '211:896') {
      l = {...l, 'x': 280, 'w': 76};
    }
    final x = numValue(l, 'x'),
        y = numValue(l, 'y'),
        w = numValue(l, 'w'),
        h = numValue(l, 'h');
    Widget child;
    switch (l['type']) {
      case 'box':
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: l['color'] == null
                ? (l['shadow'] == true ? Colors.white : null)
                : color(l['color']),
            border: l['border'] == null
                ? null
                : Border.all(color: color(l['border'])),
            borderRadius: BorderRadius.circular(
              (l['radius'] as num?)?.toDouble() ?? 0,
            ),
            boxShadow: l['shadow'] == true
                ? const [
                    BoxShadow(
                      color: Color(0x40000000),
                      offset: Offset(0, 4),
                      blurRadius: 4,
                    ),
                  ]
                : null,
            gradient: l['gradient'] == null
                ? null
                : LinearGradient(
                    begin: l['reverse'] == true
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: l['reverse'] == true
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    colors: (l['gradient'] as List)
                        .map((c) => color(c as String))
                        .toList(),
                    stops: const [0, .67788],
                  ),
          ),
        );
      case 'image':
        final asset = l['asset'] as String;
        child = Image.asset(
          asset.endsWith('.svg') ? asset.replaceAll('.svg', '.png') : asset,
          width: w,
          height: h,
          fit: l['cover'] == true ? BoxFit.cover : BoxFit.fill,
          excludeFromSemantics: true,
        );
        if (l['sourceRect'] != null) {
          final crop = (l['sourceRect'] as List).cast<num>();
          final source = (l['sourceSize'] as List).cast<num>();
          final scale = math.min(w / crop[2], h / crop[3]);
          final cropWidth = crop[2] * scale;
          final cropHeight = crop[3] * scale;
          child = Center(
            child: SizedBox(
              width: cropWidth,
              height: cropHeight,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: -crop[0] * scale,
                      top: -crop[1] * scale,
                      width: source[0] * scale,
                      height: source[1] * scale,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (screen == '211:772' && asset == 'assets/figma/1ee26.svg') {
          child = RotatedBox(quarterTurns: 1, child: child);
        }
        if ((l['radius'] as num? ?? 0) > 0) {
          child = ClipRRect(
            borderRadius: BorderRadius.circular(numValue(l, 'radius')),
            child: child,
          );
        }
        if (l['clip'] != null) {
          final clip = (l['clip'] as Map).cast<String, dynamic>();
          return Positioned(
            left: numValue(clip, 'x'),
            top: numValue(clip, 'y'),
            width: numValue(clip, 'w'),
            height: numValue(clip, 'h'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(numValue(clip, 'radius')),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: x - numValue(clip, 'x'),
                    top: y - numValue(clip, 'y'),
                    width: w,
                    height: h,
                    child: child,
                  ),
                ],
              ),
            ),
          );
        }
      default:
        var text = flowText(l);
        if (screen == '211:1046' && l['id'] == '211:1050') {
          text = hideBalance ? '••••••••••' : 'LKR ${money(balance)}';
        }
        if (screen == '211:538' && l['id'] == '211:547') {
          text = 'LKR ${money(transferAmount).replaceFirst('.00', '')}';
        }
        if (screen == '211:538' && l['id'] == '211:546') text = note.text;
        if (screen == '211:528' && l['id'] == '211:531') {
          text = 'LKR ${money(transferAmount)}';
        }
        final weight = (l['weight'] as num).toDouble();
        final style = TextStyle(
          fontFamily: l['font'] as String,
          fontSize: numValue(l, 'fontSize'),
          fontVariations: [
            FontVariation('wght', weight),
            if (l['font'] == 'Inter')
              FontVariation('opsz', numValue(l, 'fontSize')),
          ],
          fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
          fontStyle: l['italic'] == true ? FontStyle.italic : FontStyle.normal,
          color: color(l['color']),
          height: 1.21,
          letterSpacing: 0,
        );
        child = l['brand'] == true
            ? Text.rich(
                TextSpan(
                  style: style,
                  children: const [
                    TextSpan(text: 'Fin'),
                    TextSpan(
                      text: 'Trust',
                      style: TextStyle(color: Color(0xff2563eb)),
                    ),
                  ],
                ),
              )
            : Text(
                text,
                style: style,
                softWrap: false,
                overflow: TextOverflow.visible,
              );
        // Keep the original first baseline, but let Flutter rasterize text
        // consistently with editable fields at the actual device resolution.
        final glyphs = l['glyphs'] as List?;
        if (glyphs != null && glyphs.isNotEmpty) {
          child = Baseline(
            baseline: (glyphs.first['y'] as num).toDouble(),
            baselineType: TextBaseline.alphabetic,
            child: child,
          );
        }
        return Positioned(left: x, top: y, width: w, child: child);
    }
    return Positioned(left: x, top: y, width: w, height: h, child: child);
  }

  Widget hit(
    String label,
    double x,
    double y,
    double w,
    double h,
    VoidCallback action,
  ) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action,
          child: FocusableActionDetector(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  action();
                  return null;
                },
              ),
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  Widget field(
    String label,
    TextEditingController controller,
    double x,
    double y,
    double w,
    double h, {
    double size = 20,
    Color color = Colors.black,
    bool numeric = false,
    String? hint,
    String? prefix,
  }) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: Semantics(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: FontWeight.w400,
          fontVariations: [
            FontVariation('wght', 400),
            FontVariation('opsz', size),
          ],
          color: color,
          height: 1.21,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          prefixText: prefix,
          prefixStyle: TextStyle(color: color, fontSize: size),
          hintStyle: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w300,
            fontVariations: [
              FontVariation('wght', 300),
              FontVariation('opsz', size),
            ],
          ),
        ),
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,. ]'))]
            : null,
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    ),
  );
  Widget toggle(
    String label,
    double x,
    double y,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Positioned(
    left: x - 8,
    top: y - 8,
    width: 73,
    height: 44,
    child: Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Center(
          child: Container(
            width: 57,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xff0d47a1),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xffd9d9d9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget selection(double x, double y, double w, double h) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: blue, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );
  List<Widget> _controls() {
    final result = <Widget>[...prototypeLinks()];
    if (!['211:945', '211:950', '211:1046', '211:528'].contains(screen)) {
      result.add(hit('Back', 14, 44, 48, 48, back));
    }
    switch (screen) {
      case '211:945':
        result.add(
          hit('Continue to onboarding', 0, 0, 440, 956, () => go('211:950')),
        );
      case '211:950':
        result.addAll([
          hit('Next onboarding', 40, 845, 80, 56, () => go('211:966')),
          hit('Next onboarding screen', 337, 842, 65, 65, () => go('211:966')),
        ]);
      case '211:1046':
        result.addAll([
          hit('Notifications', 377, 49, 48, 48, () => go('211:813')),
          hit(
            'Toggle balance visibility',
            365,
            130,
            48,
            48,
            () => setState(() => hideBalance = !hideBalance),
          ),
          hit('Transfer money', 19, 321, 80, 110, () => go('211:1510')),
          hit('Transaction history', 123, 321, 80, 110, () => go('211:1349')),
          hit('Bill payments', 227, 321, 80, 110, () => go('211:570')),
          hit('Mobile reload', 331, 321, 80, 110, () => go('211:601')),
          hit('Budget and spending', 19, 449, 400, 100, () => go('211:772')),
          hit('Saving goals', 19, 579, 400, 100, () => go('211:740')),
          hit('See all transactions', 355, 695, 75, 45, () => go('211:1349')),
          hit('Food City transaction', 19, 745, 400, 48, () => go('211:1442')),
          hit('Salary transaction', 19, 812, 400, 48, () => go('211:1442')),
          hit(
            'Home',
            20,
            883,
            70,
            65,
            () => scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          ),
          hit('Accounts', 100, 883, 80, 65, () => go('211:1159')),
          hit('Search', 190, 883, 75, 65, () => go('211:1472')),
          hit('Cards', 270, 883, 75, 65, () => go('211:632')),
          hit('Profile', 350, 883, 80, 65, () => go('211:872')),
        ]);
      case '211:512':
        result.addAll([
          field(
            'Transfer amount',
            amount,
            60,
            350,
            320,
            45,
            size: 32,
            color: const Color(0xff0d47a1),
            numeric: true,
            prefix: 'LKR ',
          ),
          field('Transfer note', note, 88, 540, 310, 30),
          toggle(
            'Schedule transfer',
            363,
            624,
            scheduled,
            (v) => setState(() => scheduled = v),
          ),
          hit('Continue', 20, 820, 400, 55, reviewTransfer),
        ]);
      case '211:538':
        result.add(hit('Confirm transfer', 20, 820, 400, 55, confirmTransfer));
      case '211:528':
        result.addAll([
          hit('View receipt', 20, 725, 400, 55, receipt),
          hit('Make another transfer', 20, 815, 400, 55, () => go('211:1510')),
        ]);
      case '211:651':
        for (var i = 0; i < 4; i++) {
          final index = i;
          result.add(
            toggle(
              [
                'Freeze card',
                'Online payments',
                'Contactless payments',
                'ATM withdrawal',
              ][i],
              327,
              441 + i * 98,
              cardControls[i],
              (v) => setState(() => cardControls[index] = v),
            ),
          );
        }
      case '211:601':
        result.add(
          field(
            'Mobile number',
            phone,
            52,
            375,
            290,
            35,
            size: 24,
            numeric: true,
            hint: '07X XXX XXXX',
          ),
        );
        for (var i = 0; i < 4; i++) {
          final index = i, x = [20.0, 127.0, 234.0, 340.0][i];
          if (operatorIndex == i) result.add(selection(x, 170, 80, 80));
          result.add(
            hit(
              'Select ${['Airtel', 'Hutch', 'Dialog', 'Mobitel'][i]}',
              x,
              170,
              80,
              110,
              () => setState(() => operatorIndex = index),
            ),
          );
        }
        for (var i = 0; i < 6; i++) {
          final value = [50, 100, 500, 1000, 1500, 0][i];
          final x = 20.0 + (i % 3) * 134, y = 500.0 + (i ~/ 3) * 65;
          if (reloadAmount == value ||
              (i == 5 &&
                  reloadAmount != null &&
                  ![50, 100, 500, 1000, 1500].contains(reloadAmount))) {
            result.add(selection(x, y, 132, 55));
          }
          result.add(
            hit(
              value == 0 ? 'Custom amount' : 'Select LKR $value',
              x,
              y,
              132,
              55,
              () {
                if (value == 0) {
                  customReload();
                } else {
                  setState(() => reloadAmount = value);
                }
              },
            ),
          );
        }
        result.addAll([
          hit(
            'Contacts',
            365,
            362,
            55,
            55,
            () => message('Enter the mobile number manually in this demo.'),
          ),
          hit('Continue reload', 20, 800, 400, 55, reloadReview),
        ]);
      case '211:570':
        for (var i = 0; i < 7; i++) {
          final name = [
            'Electricity',
            'Water',
            'Television',
            'Connectivity',
            'School Fees',
            'Insurance',
            'Government Payments',
          ][i];
          result.add(
            hit(name, 20, 140.0 + i * 95, 400, 70, () => billForm(name)),
          );
        }
      case '211:556':
        result.addAll([
          hit(
            'Scan QR',
            20,
            130,
            200,
            35,
            () => message(
              'Camera scanning is not connected in this local prototype.',
            ),
          ),
          hit('My QR', 220, 130, 200, 35, () => unavailable('My QR')),
          hit(
            'Flashlight',
            83,
            690,
            80,
            100,
            () => message('Flashlight requires a connected camera.'),
          ),
          hit(
            'Gallery',
            280,
            690,
            80,
            100,
            () =>
                message('QR image import is not connected in this prototype.'),
          ),
        ]);
      case '211:772':
        result.add(
          hit(
            'This month',
            20,
            134,
            400,
            80,
            () => message('Showing October 2026 sample spending.'),
          ),
        );
    }
    result.addAll(flowControls());
    return result;
  }
}
