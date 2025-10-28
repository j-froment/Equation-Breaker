import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/solvedproblem.dart';
import 'package:flutter/services.dart';
// Importing the necessary packages for the OCR which are taken from https://pub.dev/packages/google_mlkit_text_recognition
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const kOrange = Color.fromARGB(255, 255, 149, 0);
// Themed color helpers (respect light/dark + HC)
Color onSurface(BuildContext c, [double opacity = 1]) =>
    Theme.of(c).colorScheme.onSurface.withOpacity(opacity);
Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;
Color surfaceVariant(BuildContext c) => Theme.of(c).colorScheme.surfaceVariant;
Color outline(BuildContext c) => Theme.of(c).colorScheme.outline;
// ==== Contrast-aware math colors ====
Color baseText(BuildContext c) => Theme.of(c).colorScheme.onSurface;

// Bright but AA+ on dark backgrounds, still readable on light.
// (Amber 300-ish & Light Blue 300-ish — tuned for >= 7:1 on #0D0D0D)
Color kConstColor(BuildContext c) {
  final hc = FontScope.of(c).highContrast;
  return hc ? const Color(0xFFFFD54F) : const Color.fromARGB(255, 255, 149, 0);
}

Color kXColor(BuildContext c) {
  final hc = FontScope.of(c).highContrast;
  return hc ? const Color(0xFF4FC3F7) : Colors.blue;
}

// Thin rule/outline color that tracks text
Color ruleColor(BuildContext c) => Theme.of(c).colorScheme.onSurface.withOpacity(0.9);

List<int> xvalleft = [];
List<int> constantsleft = [];
List<int> xvalright = [];
List<int> constantsright = [];

List<String> constantsleftValues = [];
List<String> constantsrightValues = [];
List<String> xvalleftValues = [];
List<String> xvalrightValues = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(SolvedProblemAdapter());
  await Hive.openBox<SolvedProblem>('solved_problems');
  runApp(const MyApp());
}

// OCR scanner- extracts text from images selected by the user
class OCRScanner extends StatefulWidget {
  const OCRScanner({Key? key}) : super(key: key);

  @override
  State<OCRScanner> createState() => _OCRScannerState();
}
class AB {
  final int a; // coefficient of x (blue)
  final int b; // constant total (orange)
  AB(this.a, this.b);
}

AB computeAB(String eq) {
  final canon = canonicalizeEquation(eq); // e.g., "16x=3"
  final m = RegExp(r'^\s*(-?\d+)\s*x\s*=\s*(-?\d+)\s*$').firstMatch(canon);
  if (m == null) throw FormatException('Unexpected canonical form: $canon');
  final a = int.parse(m.group(1)!);
  final b = int.parse(m.group(2)!);
  return AB(a, b);
}

class _OCRScannerState extends State<OCRScanner> {
  final ImagePicker _picker = ImagePicker();
  late final TextRecognizer _textRecognizer;

  String _recognizedText = '';
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    setState(() {
      _selectedImage = file;
      _recognizedText = 'Processing...';
    });

    final inputImage = InputImage.fromFile(file);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    setState(() {
      _recognizedText = recognizedText.text;
    });
  }

  void _returnText() {
    Navigator.pop(context, _recognizedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick Image'),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null) Image.file(_selectedImage!),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recognized Text:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_recognizedText),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _recognizedText.isNotEmpty ? _returnText : null,
              child: const Text('Use this text'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = FontPrefs(); // one shared instance for the app

    return FontScope(
      notifier: prefs,
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) {
          final theme = ThemeData(
            brightness: prefs.highContrast ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6B46C1),
              brightness: prefs.highContrast ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor:
                prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white,
          );

          // Apply text scaling globally
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: prefs.scale),
            child: MaterialApp(
              theme: theme,
              title: 'Dycalculating equations',
              home: const TextBoxExample(),
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}

String solutionStatus(int b, int a) {
  if (a == 0 && b == 0) return 'Infinitely many solutions';
  if (a == 0 && b != 0) return 'No solution';
  
  return '';
}
int gcd(int a, int b) => b == 0 ? a.abs() : gcd(b, a % b);
// ---------- FRACTIONS & LCM ----------
int lcm(int a, int b) => (a == 0 || b == 0) ? 0 : (a ~/ gcd(a, b)) * b;
// ==== Global font + contrast prefs ====
class FontPrefs extends ChangeNotifier {
  double scale = 1.0;          // 0.9 .. 1.4
  bool highContrast = false;

  void setScale(double v) {
    if (v == scale) return;
    scale = v;
    notifyListeners();
  }

  void toggleHC() {
    highContrast = !highContrast;
    notifyListeners();
  }
}

// Inherited bridge so any widget can read/update prefs without packages
class FontScope extends InheritedNotifier<FontPrefs> {
  const FontScope({super.key, required FontPrefs notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static FontPrefs of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FontScope>();
    assert(scope != null, 'FontScope not found in widget tree.');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant InheritedNotifier<FontPrefs> oldWidget) => true;
}

class Frac {
  int n; // numerator
  int d; // denominator (always > 0)
  Frac([this.n = 0, this.d = 1]) {
    if (d == 0) throw ArgumentError('denominator 0');
    _norm();
  }
  void _norm() {
    if (d < 0) { n = -n; d = -d; }
    final g = gcd(n.abs(), d);
    if (g != 0) { n ~/= g; d ~/= g; }
  }
  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d);
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d);
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d);
  Frac operator /(Frac o) {
    if (o.n == 0) throw ArgumentError('division by zero');
    return Frac(n * o.d, d * o.n);
  }
}

// Linear form: a·x + c  (a and c are fractions while parsing)
class Lin {
  Frac a, c;
  Lin(this.a, this.c);
  static Lin varX() => Lin(Frac(1,1), Frac(0,1));
  static Lin constInt(int k) => Lin(Frac(0,1), Frac(k,1));
  static Lin constFrac(Frac f) => Lin(Frac(0,1), f);

  Lin add(Lin o) => Lin(a + o.a, c + o.c);
  Lin sub(Lin o) => Lin(a - o.a, c - o.c);

  // multiply whole (a·x + c) by constant k
  Lin scale(Frac k) => Lin(a * k, c * k);
}

// ---------- TOKENIZER ----------
enum TokType { num, x, plus, minus, star, slash, lpar, rpar, end }

class Tok {
  final TokType t;
  final String? lex;
  Tok(this.t, [this.lex]);
}

class Lexer {
  final String s;
  int i = 0;
  Lexer(this.s);

  bool _isDigit(int c) => c >= 48 && c <= 57;
  bool _isSpace(int c) => c == 32 || c == 9 || c == 10 || c == 13;

  Tok next() {
    while (i < s.length && _isSpace(s.codeUnitAt(i))) i++;
    if (i >= s.length) return Tok(TokType.end);

    final ch = s[i];

    // signed integer literal
    if (_isDigit(s.codeUnitAt(i)) || (ch == '-' && i+1 < s.length && _isDigit(s.codeUnitAt(i+1)))) {
      final start = i;
      if (ch == '-') i++;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) i++;
      return Tok(TokType.num, s.substring(start, i));
    }

    i++;
    switch (ch) {
      case 'x': case 'X': return Tok(TokType.x);
      case '+': return Tok(TokType.plus);
      case '-': return Tok(TokType.minus);
      case '*': return Tok(TokType.star);
      case '/': return Tok(TokType.slash);
      case '(': return Tok(TokType.lpar);
      case ')': return Tok(TokType.rpar);
      default:
        // normalize common OCR dashes as minus
        if (ch == '−' || ch == '–' || ch == '—') return Tok(TokType.minus);
        // skip unknowns
        return next();
    }
  }
}

// ---------- PARSER (recursive descent) ----------
class Parser {
  late Lexer L;
  late Tok look;

  Lin parseSide(String side) {
    L = Lexer(side);
    look = L.next();
    final e = _expr();
    _expect(TokType.end);
    return e;
  }

  void _advance() { look = L.next(); }
  void _expect(TokType t) {
    if (look.t != t) throw FormatException('Unexpected token');
    _advance();
  }

  // expr := term (('+'|'-') term)*
  Lin _expr() {
    var v = _term();
    while (look.t == TokType.plus || look.t == TokType.minus) {
      final op = look.t;
      _advance();
      final rhs = _term();
      v = (op == TokType.plus) ? v.add(rhs) : v.sub(rhs);
    }
    return v;
  }

  // term := factor (('*'|'/') factor | implicitMult factor)*
  Lin _term() {
    var v = _factor();

    while (true) {
      // explicit * or /
      if (look.t == TokType.star || look.t == TokType.slash) {
        final op = look.t;
        _advance();
        final rhs = _factor();
        v = _mulDiv(v, rhs, isDiv: op == TokType.slash);
        continue;
      }

      // implicit multiplication: factor followed by next factor start
      if (_startsFactor(look.t)) {
        final rhs = _factor();
        v = _mulDiv(v, rhs, isDiv: false);
        continue;
      }

      break;
    }
    return v;
  }

  bool _startsFactor(TokType t) =>
      t == TokType.num || t == TokType.x || t == TokType.lpar || t == TokType.minus;

  // factor := number | x | '(' expr ')' | unary '-' factor
  Lin _factor() {
    // unary minus
    if (look.t == TokType.minus) {
      _advance();
      return _factor().scale(Frac(-1,1));
    }

    if (look.t == TokType.num) {
      final k = int.parse(look.lex!);
      _advance();
      return Lin.constInt(k);
    }

    if (look.t == TokType.x) {
      _advance();
      return Lin.varX();
    }

    if (look.t == TokType.lpar) {
      _advance();
      final inside = _expr();
      _expect(TokType.rpar);
      return inside;
    }

    throw FormatException('Bad factor');
  }

  // (a1·x + c1) (op) (a2·x + c2)
  // only allowed to multiply/divide by a CONSTANT (no x on rhs)
  Lin _mulDiv(Lin lhs, Lin rhs, {required bool isDiv}) {
    final rhsIsConst = rhs.a.n == 0;
    final lhsIsConst = lhs.a.n == 0;

    if (isDiv) {
      if (!rhsIsConst) throw FormatException('Division by an expression with x is not linear.');
      return lhs.scale(Frac(rhs.c.d, rhs.c.n)); // multiply by reciprocal
    } else {
      // multiplication
      if (rhsIsConst) return lhs.scale(rhs.c);
      if (lhsIsConst) return rhs.scale(lhs.c);
      // both have x -> would be quadratic
      throw FormatException('Multiplying expressions that both include x is not linear.');
    }
  }
}

// Turn raw input "left=right" into canonical "Ax= B" with integers
String canonicalizeEquation(String input) {
  final s = input.replaceAll(' ', '');
  final parts = s.split('=');
  if (parts.length != 2) throw FormatException('Equation must have exactly one "="');

  final p = Parser();
  final L = p.parseSide(parts[0]); // aL x + cL
  final R = p.parseSide(parts[1]); // aR x + cR

  // Move everything to the left: (aL-aR)·x + (cL-cR) = 0
  final A = L.a - R.a;
  final C = L.c - R.c;

  // Clear denominators to get integers
  var D = 1;
  D = lcm(D, A.d);
  D = lcm(D, C.d);
  if (D == 0) D = 1;

  final Ai = A.n * (D ~/ A.d);
  final Ci = C.n * (D ~/ C.d);

  // Ax + C = 0  ->  Ax = -C
  final Bi = -Ci;

  // produce clean string your current pipeline can color & step through
  return '${Ai}x=${Bi}';
}

class FractionRender {
  final String text;    // e.g., "-3/4  (= -0.750)"
  final bool isInteger; // true if denominator reduces to 1
  final int? intValue;  // integer value when isInteger == true
  FractionRender({required this.text, required this.isInteger, this.intValue});
}

FractionRender renderQuotient(int b, int a) {
  if (a == 0) return FractionRender(text: '', isInteger: false);
  final g = gcd(b, a);
  var n = b ~/ g, d = a ~/ g;
  if (d < 0) { n = -n; d = -d; }
  final decimal = (b / a).toStringAsFixed(3);
  if (d == 1) {
    return FractionRender(text: '$n', isInteger: true, intValue: n);
  } else {
    return FractionRender(text: '$n/$d  (= $decimal)', isInteger: false);
  }
}
int _safeParseInt(String s) => int.tryParse(s.trim()) ?? 0;

List<int> _reduced(int n, int d) {
  if (d == 0) return [n, d];
  if (d < 0) { n = -n; d = -d; }
  final g = gcd(n, d);
  return [n ~/ g, d ~/ g];
}

bool _fractionsEqual(int n1, int d1, int n2, int d2) {
  if (d1 == 0 || d2 == 0) return false;
  final r1 = _reduced(n1, d1);
  final r2 = _reduced(n2, d2);
  return r1[0] == r2[0] && r1[1] == r2[1];
}

bool _decimalMatchesFraction(String decStr, int n, int d, {double tol = 1e-3}) {
  final x = double.tryParse(decStr.trim());
  if (x == null || d == 0) return false;
  return (x - (n / d)).abs() <= tol;
}

/// Parses an algebraic equation to identify x terms and constants on both sides,
/// and renders them with contrast-aware colors (HC friendly).
/// NOTE: signature now takes BuildContext so we can read theme + HC.
Widget findComponents(BuildContext context, String equation) {
  // ---- contrast-aware colors ----
  final on = Theme.of(context).colorScheme.onSurface;     // base text
  final hc = FontScope.of(context).highContrast;
  // accessible accents for HC; keep your original hues for normal mode
  final xCol = hc ? const Color(0xFF4FC3F7) : Colors.blue;                         // blue-ish
  final kCol = hc ? const Color(0xFFFFD54F) : const Color.fromARGB(255, 255, 149, 0); // orange-ish

  // ---- original state resets ----
  xvalleft.clear();
  constantsleft.clear();
  xvalright.clear();
  constantsright.clear();
  constantsleftValues.clear();
  constantsrightValues.clear();
  xvalleftValues.clear();
  xvalrightValues.clear();

  equation = equation.replaceAll(' ', '');
  var left = "", right = "";

  // Split equation at '='
  for (var i = 0; i < equation.length; i++) {
    if (equation[i] == '=') {
      left = equation.substring(0, i);
      right = equation.substring(i + 1);
      break;
    }
  }

  // ---- scan LEFT ----
  int j = 0;
  while (j < left.length) {
    if (isNumeric(left[j]) || (left[j] == '-' && j + 1 < left.length && isNumeric(left[j + 1]))) {
      List<int> addval = [j];
      int check = 1;
      while (j + check < left.length && isNumeric(left[j + check])) {
        addval.add(j + check);
        check++;
      }
      if (j + check < left.length && isLetter(left[j + check])) {
        xvalleft.addAll(addval);
        xvalleft.add(j + check);
        String coeff = addval.map((index) => left[index]).join();
        xvalleftValues.add(coeff);
        j += check + 1;
      } else {
        constantsleft.addAll(addval);
        String number = addval.map((index) => left[index]).join();
        constantsleftValues.add(number);
        j += check;
      }
    } else if (isLetter(left[j])) {
      xvalleft.add(j);
      xvalleftValues.add("1");
      j++;
    } else if (left[j] == '-' && j + 1 < left.length && isLetter(left[j + 1])) {
      xvalleft.addAll([j, j + 1]);
      xvalleftValues.add("-1");
      j += 2;
    } else {
      j++;
    }
  }

  // ---- scan RIGHT ----
  int i = 0;
  while (i < right.length) {
    if (isNumeric(right[i]) || (right[i] == '-' && i + 1 < right.length && isNumeric(right[i + 1]))) {
      List<int> addval = [i];
      int check = 1;
      while (i + check < right.length && isNumeric(right[i + check])) {
        addval.add(i + check);
        check++;
      }
      if (i + check < right.length && isLetter(right[i + check])) {
        xvalright.addAll(addval);
        xvalright.add(i + check);
        String coeff = addval.map((index) => right[index]).join();
        xvalrightValues.add(coeff);
        i += check + 1;
      } else {
        constantsright.addAll(addval);
        String number = addval.map((index) => right[index]).join();
        constantsrightValues.add(number);
        i += check;
      }
    } else if (isLetter(right[i])) {
      xvalright.add(i);
      xvalrightValues.add("1");
      i++;
    } else if (right[i] == '-' && i + 1 < right.length && isLetter(right[i + 1])) {
      xvalright.addAll([i, i + 1]);
      xvalrightValues.add("-1");
      i += 2;
    } else {
      i++;
    }
  }

  // ---- pretty spaced equation (keeps indices mapping via rawIndex) ----
  String formattedEquation = '';
  final buffer = StringBuffer();
  int k = 0;
  while (k < equation.length) {
    String char = equation[k];
    if (char == '+' || char == '-' || char == '=') {
      buffer.write('  $char  ');
      k++;
    } else {
      String term = '';
      while (k < equation.length && equation[k] != '+' && equation[k] != '-' && equation[k] != '=') {
        term += equation[k];
        k++;
      }
      buffer.write(term);
    }
  }
  formattedEquation = buffer.toString();

  // ---- build colored spans with theme-aware colors ----
  List<InlineSpan> spans = [];
  int rawIndex = 0;
  for (int idx = 0; idx < formattedEquation.length; idx++) {
    String char = formattedEquation[idx];
    if (char == ' ') {
      spans.add(TextSpan(text: ' ', style: TextStyle(color: on)));
      continue;
    }

    TextStyle style = TextStyle(color: on);

    if (rawIndex < left.length) {
      if (xvalleft.contains(rawIndex)) {
        style = TextStyle(color: xCol);
      } else if (constantsleft.contains(rawIndex)) {
        style = TextStyle(color: kCol);
      }
    } else if (rawIndex == left.length) {
      style = TextStyle(color: on); // the '=' slot
    } else {
      int rightIndex = rawIndex - (left.length + 1);
      if (xvalright.contains(rightIndex)) {
        style = TextStyle(color: xCol);
      } else if (constantsright.contains(rightIndex)) {
        style = TextStyle(color: kCol);
      }
    }

    spans.add(TextSpan(text: char, style: style));
    rawIndex++;
  }

  return RichText(
    text: TextSpan(
      children: spans,
      style: TextStyle(fontSize: 24, color: on),
    ),
  );
}


String addSpacesBetweenTerms(String eq) {
  String result = '';
  int i = 0;
  while (i < eq.length) {
    String char = eq[i];
    if (char == '+' || char == '-' || char == '=') {
      result += '  $char  ';
      i++;
    } else {
      String term = '';
      while (i < eq.length && eq[i] != '+' && eq[i] != '-' && eq[i] != '=') {
        term += eq[i];
        i++;
      }
      result += term;
    }
  }
  return result.trim();
}

String simplifySigns(String equation) {
  String removeCharAt(String str, int index) {
    return str.substring(0, index) + str.substring(index + 1);
  }

  String replaceAt(String str, int index, String replacement) {
    if (index < 0 || index >= str.length) return str;
    return str.substring(0, index) + replacement + str.substring(index + 1);
  }

  for (int i = equation.length - 1; i > 0; i--) {
    if (equation[i] == '-') {
      if (equation[i - 1] == '+') {
        equation = removeCharAt(equation, i);
        equation = replaceAt(equation, i - 1, '-');
      } else if (equation[i - 1] == '-') {
        equation = removeCharAt(equation, i);
        equation = replaceAt(equation, i - 1, '+');
      }
    }
  }

  return equation;
}

String simplifyEquation(String equations) {
  List<String> equation = [];
  List<int> startIndex = [];
  List<int> endIndex = [];
  List<int> multiplier = [];
  String adding = '';
  String equationReturning = '';

  bool isInteger(String str) => int.tryParse(str) != null;

  bool isNotInteger(String str) => !isInteger(str);

  for (int i = 0; i < equations.length; i++) {
    String current = equations.substring(i, i + 1);

    if (isInteger(current)) {
      adding += current;

      if (i + 1 < equations.length && RegExp(r'[a-zA-Z]').hasMatch(equations[i + 1])) {
        adding += equations.substring(i + 1, i + 2);
        i++;
      }

      if (i + 1 == equations.length ||
          (isNotInteger(equations.substring(i + 1, i + 2)) &&
              !RegExp(r'[a-zA-Z]').hasMatch(equations[i + 1]))) {
        equation.add(adding);
        adding = '';
      }
    } else if (RegExp(r'[a-zA-Z]').hasMatch(current)) {
      equation.add(current);
    } else {
      if (adding.isNotEmpty) {
        equation.add(adding);
        adding = '';
      }

      if (current == '-' &&
          i + 1 < equations.length &&
          isInteger(equations.substring(i + 1, i + 2))) {
        adding = '-';
      } else if (current != '*') {
        equation.add(current);
      }
    }
  }

  for (int i = 0; i < equation.length; i++) {
    if (equation[i] == '(') {
      if (i == 0 || !isInteger(equation[i - 1])) {

        if (i > 0 && equation[i - 1] == '-') {
          multiplier.add(-1);
          equation[i - 1] = 'SKIP';
        } else {
          multiplier.add(1);
        }
      } else {
        multiplier.add(int.parse(equation[i - 1]));
        equation[i - 1] = 'SKIP';
      }
      startIndex.add(i);
    } else if (equation[i] == ')') {
      endIndex.add(i);
    }
  }

  for (int i = startIndex.length - 1; i >= 0; i--) {
    int start = startIndex[i];
    int end = endIndex[i];
    int mult = multiplier[i];
    List<String> distributed = [];

    for (int j = start + 1; j < end; j++) {
      String val = equation[j];
      if (val == '+' || val == '-') {
        distributed.add(val);
      } else if (isInteger(val)) {
        int value = int.parse(val);
        distributed.add((value * mult).toString());
      } else if (RegExp(r'^[+-]?\d*[a-zA-Z]$').hasMatch(val)) {
  // handles a, b, c, x, 2x, -3c, etc.
  final varChar = val.replaceAll(RegExp(r'[0-9+-]'), ''); // the letter
  var coefStr = val.substring(0, val.length - 1);         // part before the letter
  if (coefStr.isEmpty || coefStr == '+') coefStr = '1';
  if (coefStr == '-') coefStr = '-1';
  final value = int.parse(coefStr);
  distributed.add('${value * mult}$varChar');
}
    }

    for (int j = end; j >= start; j--) {
      equation.removeAt(j);
    }

    equation.insertAll(start, distributed);
  }

  // Remove 'SKIP' markers
  equation.removeWhere((element) => element == 'SKIP');

  // Combine to return string
  for (String part in equation) {
    equationReturning += part;
  }

  return equationReturning;
}

String simplifyMultiplication(String equations) {
  List<String> equation = [];
  String adding = '';
  String equationReturning = '';

  bool isInteger(String str) {
    return int.tryParse(str) != null;
  }

  for (int i = 0; i < equations.length; i++) {
    String current = equations.substring(i, i + 1);

    if (isInteger(current)) {
      adding += current;

      if (i + 1 == equations.length ||
          (!isInteger(equations.substring(i + 1, i + 2)) &&
              !RegExp(r'[a-zA-Z]').hasMatch(equations[i + 1]))) {
        equation.add(adding);
        adding = '';
      }
    } else if (RegExp(r'[a-zA-Z]').hasMatch(current)) {
      adding += current;

      if (i + 1 == equations.length ||
          (!RegExp(r'[a-zA-Z]').hasMatch(equations[i + 1]) &&
              !isInteger(equations.substring(i + 1, i + 2)))) {
        equation.add(adding);
        adding = '';
      }
    } else {
      if (adding.isNotEmpty) {
        equation.add(adding);
        adding = '';
      }
      equation.add(current);
    }
  }

  for (int i = 0; i < equation.length - 2; i++) {
    if (equation[i + 1] == '*' &&
        isInteger(equation[i]) &&
        isInteger(equation[i + 2])) {
      int mult = int.parse(equation[i]) * int.parse(equation[i + 2]);
      equation[i] = mult.toString();
      equation.removeAt(i + 2);
      equation.removeAt(i + 1);
      i = -1; // restart the loop
    }
  }

  for (int i = 0; i < equation.length; i++) {
    equationReturning += equation[i];
  }

  return equationReturning;
}

bool isNumeric(String s) {
  return double.tryParse(s) != null;
}

bool isLetter(String s) {
  if (s.length != 1) return false;
  int codeUnit = s.codeUnitAt(0);
  return (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
}
// --- normalizes "(6)(x+3)" -> "6(x+3)" so implicit-mult parser handles it
String _normalizeNumberParens(String s) =>
    s.replaceAllMapped(RegExp(r'\((\d+)\)\('), (m) => '${m[1]}(');

// Use your simplifiers to normalize an equation string.
// This lets us check student-typed steps without doing the work for them.
String _canonical(String s) =>
    simplifySigns(
      simplifyEquation(
        simplifyMultiplication(
          _normalizeNumberParens(s),
        ),
      ),
    ).replaceAll(' ', '');


bool _eqCanon(String a, String b) {
  try {
    return _canonical(a) == _canonical(b);
  } catch (_) {
    return false;
  }
}
// --- helpers used only by the PrepLCM preview ---

List<String> _splitTopLevelTerms(String side) {
  final terms = <String>[];
  final sb = StringBuffer();
  int depth = 0;

  for (int i = 0; i < side.length; i++) {
    final c = side[i];
    if (c == '(') { depth++; sb.write(c); }
    else if (c == ')') { depth = (depth > 0) ? depth - 1 : 0; sb.write(c); }
    else if ((c == '+' || c == '-') && depth == 0) {
      if (sb.isNotEmpty) { terms.add(sb.toString()); sb.clear(); }
      sb.write(c); // keep the sign with the term
    } else {
      sb.write(c);
    }
  }
  if (sb.isNotEmpty) terms.add(sb.toString());
  return terms;
}
// Multiply a whole equation-side by k and write a readable preview.
// It distributes across top-level +/− terms and does simple numeric/coef updates.
String _distributeSide(String side, int k) {
  final terms = _splitTopLevelTerms(side); // keeps leading sign with each term
  final out = <String>[];

  // helpers
  String trimSign(String s) => s.trimLeft();
  String withSign(String sign, String body) => '$sign$body';

  final reFrac   = RegExp(r'^-?\d+\s*/\s*\d+$');      // 12/5, -7/10
  final reInt    = RegExp(r'^-?\d+$');               // 3, -4
  final reCoefX  = RegExp(r'^(-?\d+)\s*[xX]$');      // 2x, -3x
  final reLoneX  = RegExp(r'^[xX]$');                // x
  bool isParen(String s) => s.startsWith('(') && s.endsWith(')');

  for (var raw in terms) {
    if (raw.isEmpty) continue;

    // separate leading sign from the body
    var sign = '';
    var body = raw;
    if (body.startsWith('+') || body.startsWith('-')) {
      sign = body[0];
      body = body.substring(1);
    }
    body = trimSign(body);

    // cases
    if (reInt.hasMatch(body)) {
      // k * integer
      final v = int.parse(body);
      out.add(withSign(sign.isEmpty ? '+' : sign, (k * v).toString()));
    } else if (reCoefX.hasMatch(body)) {
      // k * (c x)  -> (k*c)x
      final m = reCoefX.firstMatch(body)!;
      final c = int.parse(m.group(1)!);
      out.add(withSign(sign.isEmpty ? '+' : sign, '${k * c}x'));
    } else if (reLoneX.hasMatch(body)) {
      // k * x  -> kx
      out.add(withSign(sign.isEmpty ? '+' : sign, '${k}x'));
    } else if (reFrac.hasMatch(body)) {
      // keep as k* (n/d) so your preview can highlight the cancelling parts
      out.add(withSign(sign.isEmpty ? '+' : sign, '$k*${body.replaceAll(' ', '')}'));
    } else if (isParen(body)) {
      // don't expand nested groups here; show k* ( ... )
      out.add(withSign(sign.isEmpty ? '+' : sign, '$k*$body'));
    } else {
      // fallback: write k*term
      out.add(withSign(sign.isEmpty ? '+' : sign, '$k*$body'));
    }
  }

  // join, dropping a leading '+'
  if (out.isEmpty) return '';
  var s = out.join('');
  if (s.startsWith('+')) s = s.substring(1);
  return s;
}

/// Build TextSpans for the distributed preview, turning numeric fractions
/// into stacked glyphs and coloring the canceling LCM 'k' in red:
///  - color any standalone number == k when it is directly followed by `*`
///    and the thing after `*` is a number (NOT a letter like x).
///  - color any denominator equal to k in a numeric fraction.

  // Build TextSpans for the distributed preview, turning fractions into stacked
// glyphs and coloring the canceling LCM k in red.
List<InlineSpan> buildCancelPreviewSpans(String input, int k, {double fontSize = 16}) {
  final spans = <InlineSpan>[];
  final red = const Color(0xFFE53935);

  int skipSpaces(String s, int i) {
    while (i < s.length && s[i] == ' ') i++;
    return i;
  }

  // Fraction patterns: allow ( ... ), x-terms, and plain integers
  final patterns = <RegExp>[
    // ( ... ) / ( ... )
    RegExp(r'^(\([^()]+\))\s*/\s*(\([^()]+\))'),
    // ( ... ) / (x-term or int)
    RegExp(r'^(\([^()]+\))\s*/\s*(-?(?:\d+[xX]|[xX]|\d+))\b'),
    // (x-term) / ( ... )
    RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(\([^()]+\))'),
    // x-term / x-term
    RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(-?(?:\d+[xX]|[xX]))\b'),
    // x-term / int
    RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(-?\d+)\b'),
    // int / x-term
    RegExp(r'^(-?\d+)\s*/\s*(-?(?:\d+[xX]|[xX]))\b'),
    // int / int
    RegExp(r'^(-?\d+)\s*/\s*(-?\d+)\b'),
  ];

  int i = 0;
  while (i < input.length) {
    // Keep literal spaces so "=" spacing looks good
    if (input[i] == ' ') {
      spans.add(TextSpan(
        text: ' ',
        style: TextStyle(fontSize: fontSize, height: 1.3, fontFamily: 'monospace', color: Colors.black),
      ));
      i++;
      continue;
    }

    final rest = input.substring(i);

    // 1) Try any fraction
    Match? m;
    for (final p in patterns) {
      m = p.firstMatch(rest);
      if (m != null) break;
    }
    if (m != null) {
      final numStr = m!.group(1)!.trim();
      final denStr = m.group(2)!.trim();

      // Color denominator red if it is exactly the LCM k (numeric)
      final dVal = int.tryParse(denStr.replaceAll(RegExp(r'^\(|\)$'), ''));
      final dIsK  = dVal != null && dVal == k;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          baseline: TextBaseline.alphabetic,
          child: Container(
  decoration: BoxDecoration(
    color: dIsK ? const Color(0xFFE53935).withOpacity(0.12) : null,
    borderRadius: BorderRadius.circular(4),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 2),
  child: FractionGlyph(
    numerator: numStr,
    denominator: denStr,
    fontSize: fontSize * 0.95,
    denominatorColor: dIsK ? red : null,
  ),
),

        ),
      );
      i += m.group(0)!.length;
      continue;
    }

    // 2) Standalone integer (possible "k * something")
    final mNum = RegExp(r'^(-?\d+)\b').firstMatch(rest);
    if (mNum != null) {
      final full = mNum.group(0)!;
      final nStr = mNum.group(1)!;
      final nVal = int.tryParse(nStr);

      bool highlight = false;
      if (nVal != null && nVal == k) {
        int j = i + full.length;
        j = skipSpaces(input, j);
        if (j < input.length && input[j] == '*') {
          j++;
          j = skipSpaces(input, j);
          // highlight when the next token begins with a digit OR '('
          if (j < input.length && (RegExp(r'\d').hasMatch(input[j]) || input[j] == '(')) {
            highlight = true;
          }
        }
      }

      spans.add(TextSpan(
        text: full,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.3,
          fontFamily: 'monospace',
          color: highlight ? red : Colors.black,
        ),
      ));
      i += full.length;
      continue;
    }

    // 3) Fallback: a single character
    spans.add(TextSpan(
      text: input[i],
      style: TextStyle(fontSize: fontSize, height: 1.3, fontFamily: 'monospace', color: Colors.black),
    ));
    i++;
  }

  return spans;
}
    


// Build the string you’d expect after “multiply both sides by k”
String _mulBothSides(String eq, int k) {
  final parts = eq.replaceAll(' ', '').split('=');
  if (parts.length != 2) throw FormatException('bad equation');
  // was: '($k)(${parts[0]})=($k)(${parts[1]})'
    return '$k(${parts[0]})=$k(${parts[1]})';

}


// Tiny scanners used to decide which prep steps to show
bool _hasSlash(String s) => s.contains('/');
bool _hasParens(String s) => s.contains('(');

class TextBoxExample extends StatefulWidget {
  const TextBoxExample({super.key});
  @override
  State<TextBoxExample> createState() => _TextBoxExampleState();
}

class _TextBoxExampleState extends State<TextBoxExample> {
  List<SolvedProblem> history = [];
  String? selectedEquation;
  String? selectedEquationToDelete;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  void loadHistory() {
    final box = Hive.box<SolvedProblem>('solved_problems');
    setState(() {
      history = box.values.toList().reversed.toList();
    });
  }

  void _startNewProblem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrepPage(rawInput: '')),
    ).then((_) => loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prep a new equation'),
        backgroundColor: const Color.fromRGBO(236,229,243,1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Single entry point: users type/scan on PrepPage only
            ElevatedButton(
              onPressed: _startNewProblem,
              child: const Text('New problem'),
            ),
            const SizedBox(height: 24),

            // ---- Past Problems ----
            const Text(
              "Past Problems",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Select a past problem"),
              value: selectedEquation,
              items: history.map((problem) {
                return DropdownMenuItem<String>(
                  value: problem.equation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(problem.equation, style: const TextStyle(fontSize: 16)),
                     Text(
  "Answer = ${problem.finalAnswerText ?? problem.finalAnswer?.toString() ?? '?'}",
  style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 158, 158, 158)),
),

                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedEquation = value);
                final selectedProblem = history.firstWhere((p) => p.equation == value);
                Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PrepPage(rawInput: selectedProblem.equation),
  ),
);

              },
            ),

            const SizedBox(height: 24),

            // ---- Delete a Past Problem ----
            const Text(
              "Delete a Past Problem",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Select a problem to delete"),
              value: selectedEquationToDelete,
              items: history.map((problem) {
                return DropdownMenuItem<String>(
                  value: problem.equation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(problem.equation, style: const TextStyle(fontSize: 16)),
                      Text(
  "Answer = ${problem.finalAnswerText ?? problem.finalAnswer?.toString() ?? '?'}",
  style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 230, 8, 8)),
),

                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedEquationToDelete = value),
            ),
            ElevatedButton(
              onPressed: selectedEquationToDelete == null
                  ? null
                  : () {
                      final box = Hive.box<SolvedProblem>('solved_problems');
                      final toDelete = box.values.firstWhere(
                        (p) => p.equation == selectedEquationToDelete,
                        orElse: () => SolvedProblem(
                          equation: '',
                          step1Answer: 0,
                          step2Answer: 0,
                          finalAnswer: 0,
                          solvedAt: DateTime.now(),
                        ),
                      );
                      final key = box.keyAt(box.values.toList().indexOf(toDelete));
                      box.delete(key);
                      setState(() {
                        selectedEquationToDelete = null;
                        loadHistory();
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Selected Problem'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- UI helper: Step A card (Clear Fractions without rewriting k(·)=k(·)) ---
class PrepLCMCard extends StatefulWidget {
  final String working;
  final void Function(String newWorking) onApplied;
  const PrepLCMCard({super.key, required this.working, required this.onApplied});

  @override
  State<PrepLCMCard> createState() => _PrepLCMCardState();
}

class _PrepLCMCardState extends State<PrepLCMCard> {
  late TextEditingController _lcmCtl;
  final _typedCtl = TextEditingController();

  String? _error; // inline message for the student
  String? _feedback;   // ✅ success message
  bool _ok = false;    // used to show green state

  List<int> _scanDenoms(String s) {
    final r = RegExp(r'/\s*([0-9]+)');
    return r
        .allMatches(s)
        .map((m) => int.tryParse(m.group(1)!) ?? 1)
        .where((x) => x > 1)
        .toList();
  }

  int _lcmAll(Iterable<int> xs) {
    int res = 1;
    for (final v in xs) res = lcm(res, v);
    return res <= 0 ? 1 : res;
  }

  @override
  void initState() {
    super.initState();
    final denoms = _scanDenoms(widget.working);
    final guess = denoms.isEmpty ? 1 : _lcmAll(denoms);
    _lcmCtl = TextEditingController(text: guess.toString());
  }

  @override
  void dispose() {
    _lcmCtl.dispose();
    _typedCtl.dispose();
    super.dispose();
  }

 String _previewMultiplied() {
  final k = int.tryParse(_lcmCtl.text) ?? 0;
  if (k <= 0) return '';
  try {
    final parts = widget.working.replaceAll(' ', '').split('=');
    if (parts.length != 2) return '';
    final left  = _distributeSide(parts[0], k);
    final right = _distributeSide(parts[1], k);
    return '$left  =  $right';
  } catch (_) {
    return '';
  }
}


  void _check() {
  setState(() { _error = null; _feedback = null; _ok = false; });

  final k = int.tryParse(_lcmCtl.text);
  if (k == null || k <= 0) {
    setState(() => _error = 'Enter a positive LCM.');
    return;
  }

  final preview = _previewMultiplied();
  final typed   = _typedCtl.text.trim();

  if (typed.isEmpty) {
    setState(() => _error = 'Type the equation after clearing fractions.');
    return;
  }

  bool sameAsMultiplied;
  try {
    sameAsMultiplied =
        canonicalizeEquation(typed) == canonicalizeEquation(preview);
  } catch (_) {
    sameAsMultiplied = false;
  }
  final noFractions = !_hasSlash(typed);

  if (!sameAsMultiplied && preview.isNotEmpty) {
    setState(() => _error =
        'Your line isn’t equivalent to the ×LCM preview. Check signs/parentheses.');
    return;
  }
  if (!noFractions) {
    setState(() => _error = 'Fractions must be cleared (no slashes).');
    return;
  }

  setState(() { _ok = true; _feedback = '✅ Great — you cleared all fractions correctly!'; });

  widget.onApplied(typed);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Great — fractions cleared. Now distribute parentheses.')),
  );
}


  @override
  Widget build(BuildContext context) {
    final denoms = _scanDenoms(widget.working);
    final preview = _previewMultiplied();
    final kVal = int.tryParse(_lcmCtl.text) ?? 0; // <-- ADD THIS


    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step A — Clear Fractions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (denoms.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Denominators seen:'),
                  ...denoms.map((d) => Chip(label: Text(d.toString()))),
                ],
              )
            else
              const Text('No denominators detected.'),
  const SizedBox(height: 8),

  _ExplainBox(
    text: 'To remove fractions, multiply both sides by the Least Common Multiple (LCM) of all denominators.',
    examples: const [
      'Find denominators on both sides (e.g., 3 and 4).',
      'LCM(3, 4) = 12 → multiply every top-level term by 12.',
      'This cancels the ÷3 and ÷4 so there are no slashes left.',
    ],
  ),
  const SizedBox(height: 8),

  if (denoms.isNotEmpty)

            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _lcmCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'LCM',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}), // refresh preview
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: preview.isEmpty
                      ? null
                      : () {
                          // paste preview into the student input to start from
                          _typedCtl.text = preview;
                          setState(() {});
                        },
                  child: const Text('Paste preview'),
                ),
              ],
            ),

            const SizedBox(height: 10),
           if (preview.isNotEmpty)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Preview of ×LCM (both sides):',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 6),

      // Pretty-up only for display
      Builder(builder: (_) {
        final shown = addSpacesBetweenTerms(preview).replaceAll('*', ' × ');
        return RichText(
          text: TextSpan(
            children: buildCancelPreviewSpans(shown, kVal, fontSize: 28),
          ),
        );
      }),
    ],
  ),
  const SizedBox(height: 6),
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: preview.isEmpty
      ? const SizedBox.shrink()
      : Text(
          'Multiply both sides by $kVal',
          key: ValueKey(kVal),
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
),



            const SizedBox(height: 12),
            TextField(
  controller: _typedCtl,
  minLines: 1,
  maxLines: 3,
  style: const TextStyle(
    fontSize: 22,
    fontFamily: 'monospace'
  ),
  decoration: const InputDecoration(
    hintText: 'Type your equation after clearing fractions (no slashes)',
    hintStyle: TextStyle(fontSize: 20),
    border: OutlineInputBorder(),
    isDense: false,
    contentPadding: EdgeInsets.symmetric(
      vertical: 16,
      horizontal: 12,
    ),
  ),
  onChanged: (_) => setState(() {}),   // <— add this
),
const SizedBox(height: 8),
const Text('Your line preview:', style: TextStyle(fontSize: 12, color: Colors.black54)),
MathPreviewBox(eq: _typedCtl.text, fontSize: 22),


if (_feedback != null && _ok)
  Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFB7E0B2)),
    ),
    child: Text(_feedback!, style: const TextStyle(color: Colors.green, fontSize: 13)),
  ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(onPressed: _check, child: const Text('Check')),
                const SizedBox(width: 8),
                const Text('Goal: no "/" and equivalent to the ×LCM preview.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




// --- UI helper: Step B card (Distribute Parentheses) ---
class DistributeCard extends StatefulWidget {
  final String working;
  final void Function(String newWorking) onDistributed;
  const DistributeCard({super.key, required this.working, required this.onDistributed});

  @override
  State<DistributeCard> createState() => _DistributeCardState();
}

class _DistributeCardState extends State<DistributeCard> {
  final _typedCtl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _typedCtl.dispose();
    super.dispose();
  }

  int _parenCount(String s) => RegExp(r'\(').allMatches(s).length;

  void _check() {
    setState(() => _error = null);

    final typed = _typedCtl.text.trim();
    if (typed.isEmpty) {
      setState(() => _error = 'Type your distributed line.');
      return;
    }

    final eqOK = _eqCanon(typed, widget.working);
    final before = _parenCount(widget.working);
    final after  = _parenCount(typed);

    if (!eqOK) {
      setState(() => _error = 'Not equivalent to the previous line. Check signs and distribution.');
      return;
    }
    if (after > before) {
      setState(() => _error = 'You increased parentheses; distribute more or simplify.');
      return;
    }

    widget.onDistributed(typed);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Good distribution step!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final before = _parenCount(widget.working);
    final after  = _parenCount(_typedCtl.text);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step B — Distribute Parentheses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Expand k( … ) → k·… and simplify. Keep it equivalent.'),
            const SizedBox(height: 10),

            const Text('Start:', style: TextStyle(fontSize: 14, color: Colors.black54)),
MathPreviewBox(eq: widget.working, fontSize: 22),


            const SizedBox(height: 10),
            TextField(
              controller: _typedCtl,
              minLines: 1, maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your next line after distributing',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}), // live paren count
            ),
const SizedBox(height: 8),
const Text('Your line preview:', style: TextStyle(fontSize: 12, color: Colors.black54)),
MathPreviewBox(eq: _typedCtl.text, fontSize: 22),

            const SizedBox(height: 8),
            Text('Parentheses: $before → $after',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 10),
            ElevatedButton(onPressed: _check, child: const Text('Check distribution')),
          ],
        ),
      ),
    );
  }
}
/// Draws a stacked fraction like
///    num
///   ─────
///    den
class Fraction extends StatelessWidget {
  final String numerator;
  final String denominator;
  final double fontSize;
  final double barThickness;
  final EdgeInsets padding;

  const Fraction({
    super.key,
    required this.numerator,
    required this.denominator,
    this.fontSize = 22,
    this.barThickness = 1.2,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final numStyle = TextStyle(fontSize: fontSize * 0.95, height: 1.0);
    final denStyle = TextStyle(fontSize: fontSize * 0.95, height: 1.0);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(numerator, style: numStyle),
          Container(
            height: barThickness,
            width: (numerator.length > denominator.length
                    ? numerator.length : denominator.length) * (fontSize * 0.55),
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.black,
          ),
          Text(denominator, style: denStyle),
        ],
      ),
    );
  }
}

/// Converts plain numeric fractions like "12/5" or "-7 / 10"
/// (not adjacent to letters) into stacked Fraction widgets.
/// Everything else becomes TextSpans.
///
/// NOTE: it will NOT convert "x/3" or "2x/5" (these are not pure numeric).
  // New: pretty-print fractions where numerator/denominator can be
//  - parenthesized expression: (3x+4)
//  - a single x-term: x, -x, 3x, -12x
//  - a plain integer: 7, -5
List<InlineSpan> buildPrettyMathSpans(String input, {double fontSize = 22}) {
  final spans = <InlineSpan>[];

  // Try more specific patterns first, then fall back to numeric-only
 final patterns = <RegExp>[
  RegExp(r'^(\([^()]+\))\s*/\s*(\([^()]+\))'),
  RegExp(r'^(\([^()]+\))\s*/\s*(-?(?:\d+[xX]|[xX]|\d+))\b'),
  RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(\([^()]+\))'),
  RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(-?(?:\d+[xX]|[xX]))\b'),
  RegExp(r'^(-?(?:\d+[xX]|[xX]))\s*/\s*(-?\d+)\b'),
  RegExp(r'^(-?\d+)\s*/\s*(-?(?:\d+[xX]|[xX]))\b'),
  RegExp(r'^(-?\d+)\s*/\s*(-?\d+)\b'),
];


  int i = 0;
  while (i < input.length) {
    final rest = input.substring(i);

    Match? m;
    for (final p in patterns) {
      m = p.firstMatch(rest);
      if (m != null) break;
    }

    if (m != null) {
      final numStr = m!.group(1)!.trim();
      final denStr = m.group(2)!.trim();

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          baseline: TextBaseline.alphabetic,
          child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 2),
  child: FractionGlyph(
    numerator: numStr,
    denominator: denStr,
    fontSize: fontSize,
  ),
),

        ),
      );

      i += m.group(0)!.length; // advance past the whole match
      continue;
    }

    // No fraction at this point—emit one character (preserve spacing)
    spans.add(TextSpan(
      text: input[i],
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'monospace',
        height: 1.3,
        color: Colors.black,
      ),
    ));
    i++;
  }

  return spans;
}



class PrettyEq extends StatelessWidget {
  final String eq;
  final double fontSize;
  const PrettyEq(this.eq, {super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    // Keep your spacing helper so “(3x+4)/4 = x/3” becomes more legible first
    final spaced = addSpacesBetweenTerms(eq);
    final spans  = buildPrettyMathSpans(spaced, fontSize: fontSize);
    return SelectableText.rich(TextSpan(children: spans));
  }
}


/// Renders a stacked (numeric) fraction that lines up inside text.
class FractionGlyph extends StatelessWidget {
  final String numerator;
  final String denominator;
  final double fontSize;
  final Color? numeratorColor;
  final Color? denominatorColor;

  const FractionGlyph({
    super.key,
    required this.numerator,
    required this.denominator,
    required this.fontSize,
    this.numeratorColor,
    this.denominatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context)
        .style
        .copyWith(fontSize: fontSize, fontFamily: 'monospace', height: 1.1);

    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(numerator, style: base.copyWith(color: numeratorColor)),
          Container(height: 1, color: Colors.black),
          Text(denominator, style: base.copyWith(color: denominatorColor)),
        ],
      ),
    );
  }
}




class PrepPage extends StatefulWidget {
  final String rawInput;
  const PrepPage({super.key, required this.rawInput});

  @override
  State<PrepPage> createState() => _PrepPageState();
}

class _PrepPageState extends State<PrepPage> {
  // ---- Step 0: entry + validation ----
  final _eqCtl = TextEditingController();
  final _eqFocus = FocusNode();

  String? _entryError;            // plain-language parse error
  bool _canStart = false;         // <— ADDED: used by the Start button

  // ---- Stage control ----
  int _stage = 0;                 // 0 = entry/validate, 1 = prep flow
  late String working;            // frozen equation after we start prep
  bool needFractions = false;
  bool needParens = false;

  // Scales text using global FontPrefs (no per-screen _fontScale)
  TextStyle _scalable(TextStyle base) {
    final prefs = FontScope.of(context);
    return base.copyWith(fontSize: (base.fontSize ?? 16) * prefs.scale);
  }




  @override
  void initState() {
    super.initState();
    _eqCtl.text = widget.rawInput.trim();
    _validateEntry(_eqCtl.text);
  }

  @override
  void dispose() {
    _eqCtl.dispose();
    _eqFocus.dispose();
    super.dispose();
  }

  // ===== helpers =====
  void _insert(String s) {
    final sel = _eqCtl.selection;
    final text = _eqCtl.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final next = text.replaceRange(start, end, s);
    _eqCtl.text = next;
    final caret = start + s.length;
    _eqCtl.selection = TextSelection.collapsed(offset: caret);
    _validateEntry(next);
  }

  Future<void> _openOCR() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const OCRScanner()));
    if (result is String && result.isNotEmpty) {
      _eqCtl.text = result.trim();
      _eqCtl.selection = TextSelection.collapsed(offset: _eqCtl.text.length);
      _validateEntry(_eqCtl.text);
      FocusScope.of(context).requestFocus(_eqFocus);
    }
  }

  void _validateEntry(String input) {
    setState(() {
      _entryError = null;
      _canStart = false;

      final s = input.trim();
      if (s.isEmpty) {
        _entryError = 'Type an equation like 2x + 3 = 11';
        return;
      }
      if (!s.contains('=')) {
        _entryError = 'Add one "=" so it looks like left = right';
        return;
      }
      // Try your parser + canonicalizer to ensure it’s linear
      try {
        canonicalizeEquation(s); // will throw on non-linear/invalid
      } catch (e) {
        _entryError = 'I can’t read that as a linear equation. Check signs/parentheses.';
        return;
      }
      _canStart = true;
    });
  }

  void _startPrep() {
    if (!_canStart) return;
    setState(() {
      _stage = 1;
      working = _eqCtl.text.trim();
      needFractions = _hasSlash(working);
      needParens = _hasParens(working);
    });
  }

  
  // ====== UI ======
 @override
Widget build(BuildContext context) {
  final prefs = FontScope.of(context);
  final hcBg = prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white;
  final hcFg = prefs.highContrast ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prep: you do the setup'),
        backgroundColor: const Color.fromRGBO(236,229,243,1),
        actions: const [GlobalA11yActions()],

      ),
      body: Container(
        color: hcBg,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== Step 0: Enter & validate =====
            if (_stage == 0) ...[
              Text('Step 0 — Enter your equation', style: _scalable(const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))),
              const SizedBox(height: 8),
              TextField(
                controller: _eqCtl,
                focusNode: _eqFocus,
                style: _scalable(TextStyle(color: hcFg)),
                decoration: InputDecoration(
                  hintText: 'e.g., (x/3) + 2 = 11',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Scan from image',
                    icon: const Icon(Icons.document_scanner_outlined),
                    onPressed: _openOCR,
                  ),
                ),
                onChanged: _validateEntry,
              ),
              const SizedBox(height: 10),

              // Large math keypad
             // Large math keypad
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    // …buttons…
  ],
),
const SizedBox(height: 12),
Text('Preview', style: _scalable(const TextStyle(fontSize: 14, color: Colors.black54))),
Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: prefs.highContrast ? const Color(0xFF1A1A1A) : const Color(0xFFF7F5FB),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0xFFE3DAF3)),
  ),
  child: PrettyEq(_eqCtl.text, fontSize: 22),
),



             

              const SizedBox(height: 8),
              if (_entryError != null)
                Text(_entryError!, style: _scalable(const TextStyle(color: Colors.red, fontSize: 13))),
              if (_entryError == null)
                Text('Looks good — linear and readable.', style: _scalable(const TextStyle(color: Colors.green, fontSize: 13))),

              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _canStart ? _startPrep : null,
                child: const Text('Start Prep'),
              ),
            ],

            // ===== Stage 1: your existing flow (unchanged logic) =====
            if (_stage == 1) ...[
                // compute once (statements are OK here because we’re still inside the list
  // spread, but we must produce a value, so use a final expression)
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: LinearProgressIndicator(
      value: _hasSlash(working)
          ? 0.33
          : (_hasParens(working) ? 0.66 : 1.0),
      color: Colors.deepPurple,
      backgroundColor: Colors.deepPurple.withOpacity(0.15),
    ),
  ),


              Text('Current', style: _scalable(const TextStyle(fontSize: 14, color: Colors.black54))),
PrettyEq(working, fontSize: 22),
              
              const SizedBox(height: 8),

              if (needFractions)
                PrepLCMCard(
                  working: working,
                  onApplied: (newWorking) {
                    setState(() {
                      working = newWorking;
                      needFractions = _hasSlash(working);
                      needParens   = _hasParens(working);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nice! Fractions step accepted.')),
                    );
                  },
                ),

              if (!needFractions && needParens)
                DistributeCard(
                  working: working,
                  onDistributed: (newWorking) {
                    setState(() {
                      working = newWorking;
                      needParens = _hasParens(working);
                    });
                  },
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_hasSlash(working)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clear fractions first.')));
                    return;
                  }
                  if (_hasParens(working)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distribute parentheses first.')));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EquationPage(equation: working)));
                },
                child: const Text('I’m ready for Step 1'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Big friendly keypad button
class _KeyBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highContrast;
  const _KeyBtn({required this.label, required this.onTap, required this.highContrast});

  @override
  Widget build(BuildContext context) {
    final bg = highContrast ? const Color(0xFF262626) : const Color(0xFFF1ECFA);
    final fg = highContrast ? Colors.white : Colors.black87;
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
class GlobalA11yActions extends StatelessWidget {
  const GlobalA11yActions({super.key});
  @override
  Widget build(BuildContext context) {
    final prefs = FontScope.of(context);
    return Row(children: [
      const Icon(Icons.text_increase, size: 18),
      SizedBox(
        width: 140,
        child: Slider(
          value: prefs.scale,
          min: 0.9,
          max: 1.4,
          divisions: 5,
          onChanged: prefs.setScale,
        ),
      ),
      IconButton(
        tooltip: 'High contrast',
        icon: Icon(prefs.highContrast ? Icons.visibility : Icons.visibility_outlined),
        onPressed: prefs.toggleHC,
      ),
    ]);
  }
}

// ---------- Reusable UI helpers for clear instructions & visuals ----------
class MathPreviewBox extends StatelessWidget {
  final String eq;
  final double fontSize;
  const MathPreviewBox({super.key, required this.eq, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DAF3)),
      ),
      child: PrettyEq(eq, fontSize: fontSize),
    );
  }
}

class LegendBar extends StatelessWidget {
  const LegendBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children:  [
        _LegendDot(color: Color.fromARGB(255, 255, 149, 0), label: 'orange = constants'),
        _LegendDot(color: Colors.blue, label: 'blue = x-coefficients'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class InstructionBanner extends StatelessWidget {
  final String title;
  final List<String> bullets;
  const InstructionBanner({super.key, required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(b, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
class _ExplainBox extends StatelessWidget {
  final String text;
  final List<String> examples;
  const _ExplainBox({required this.text, required this.examples});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D2FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final ex in examples)
            Text('• $ex', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String text;
  final Color color;
  const _FeedbackCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class ExampleCard extends StatelessWidget {
  final String caption;
  final Widget body;
  const ExampleCard({super.key, required this.caption, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: const Color(0xFFFDFBFF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

class EquationPage extends StatefulWidget {
  final String equation;
  final int? correctAnswerOverride;

  const EquationPage({super.key, required this.equation, this.correctAnswerOverride});
  @override
  State<EquationPage> createState() => _EquationPageState();
}

class _EquationPageState extends State<EquationPage> {
  final TextEditingController _answerController = TextEditingController();
  int correctAnswer = 0;

  int getSum(List<String> values) {
    return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
  }

  // Helper to compute step 2 answer
  int getStep2Answer() {
    int leftSum = getSum(xvalleftValues);
    int rightSum = getSum(xvalrightValues);
    return leftSum - rightSum;
  }

  @override
void initState() {
  super.initState();
  final ab = computeAB(widget.equation);   // b = orange total
  final b = ab.b;
  correctAnswer = widget.correctAnswerOverride ?? b;
  if (widget.correctAnswerOverride != null) {
    _answerController.text = correctAnswer.toString();
  }
}


  void checkAnswer() {
    int? userAnswer = int.tryParse(_answerController.text);
    if (userAnswer != null && userAnswer == correctAnswer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StepTwoPage(
            equation: widget.equation,
            correctAnswerOverride: widget.correctAnswerOverride != null ? getStep2Answer() : null,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect, try again!')),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  // read global a11y prefs
  final prefs = FontScope.of(context);
  final hcBg = prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white;

  

  return Scaffold(
    appBar: AppBar(
      title: const Text("Step One"),
      backgroundColor: const Color.fromRGBO(236,229,243,1),
      // ✅ add the size slider + HC toggle here
      actions: const [GlobalA11yActions()],
    ),
    // ✅ make the page react to high-contrast toggle
    body: Container(
      color: hcBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Step one:',
                style: TextStyle(fontSize: 20),
              ),

              // your colored equation (this respects MediaQuery.textScaleFactor)
              findComponents(context, widget.equation)
,


              const SizedBox(height: 10),
              const LegendBar(),

              InstructionBanner(
                title: 'What to do',
                bullets: const [
                  'Add the orange numbers on the RIGHT.',
                  'Subtract the orange numbers on the LEFT from that sum.',
                  'Type the total in the box.',
                ],
              ),

              ExampleCard(
                caption: 'Example',
                body: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, color: Colors.black),
                    children: [
                      TextSpan(text: 'On  '),
                      TextSpan(text: '3x + '),
                      TextSpan(text: '5', style: TextStyle(color: Color.fromARGB(255, 255, 149, 0))),
                      TextSpan(text: '  =  '),
                      TextSpan(text: '17', style: TextStyle(color: Color.fromARGB(255, 255, 149, 0))),
                      TextSpan(text: ', do  '),
                      TextSpan(text: '17 ', style: TextStyle(color: Color.fromARGB(255, 255, 149, 0))),
                      TextSpan(text: '− '),
                      TextSpan(text: '5',  style: TextStyle(color: Color.fromARGB(255, 255, 149, 0))),
                      TextSpan(text: '  =  12'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Add all the orange numbers on the right side together. Then subtract the orange numbers on the left side from that sum.',
                style: TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),
Builder(
  builder: (_) {
    String breakdown = '';
    if (constantsrightValues.isNotEmpty) {
      breakdown = constantsrightValues.join(' + ');
    } else {
      breakdown = '0';
    }
    for (final val in constantsleftValues) {
      breakdown += ' - $val';
    }
    breakdown += ' = ';
    return Text(
      breakdown,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 255, 149, 0),
      ),
      textAlign: TextAlign.center,
    );
  },
),
const SizedBox(height: 10),
SizedBox(
  width: 100,
  child: TextField(
    controller: _answerController,
    // ...

                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '?',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: checkAnswer,
                child: const Text('Check Answer'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class StepTwoPage extends StatefulWidget {
  final String equation;
  final int? correctAnswerOverride;
  const StepTwoPage({super.key, required this.equation, this.correctAnswerOverride});
  @override
  State<StepTwoPage> createState() => _StepTwoPageState();
}

class _StepTwoPageState extends State<StepTwoPage> {
  final TextEditingController _answerController = TextEditingController();
  int correctAnswer = 0;

  int getSum(List<String> values) {
    return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
  }

  int getStep3Answer() {
    int step1Right = getSum(constantsrightValues);
    int step1Left = getSum(constantsleftValues);
    int step1Result = step1Right - step1Left;
    int step2Left = getSum(xvalleftValues);
    int step2Right = getSum(xvalrightValues);
    int step2Result = step2Left - step2Right;
    return step2Result != 0 ? (step1Result / step2Result).round() : 0;
  }

 @override
void initState() {
  super.initState();
  final ab = computeAB(widget.equation);  // a = blue total
  final a = ab.a;
  correctAnswer = widget.correctAnswerOverride ?? a;
  if (widget.correctAnswerOverride != null) {
    _answerController.text = correctAnswer.toString();
  }
}


  String buildStep2Equation() {
    String result = '';
    for (int i = 0; i < xvalleftValues.length; i++) {
      if (i != 0) result += ' + ';
      result += xvalleftValues[i];
    }
    for (String val in xvalrightValues) {
      result += ' - $val';
    }
    result += ' = ?';
    return result;
  }

  void checkAnswer() {
    int? userAnswer = int.tryParse(_answerController.text);
    if (userAnswer != null && userAnswer == correctAnswer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StepThreePage(
            equation: widget.equation,
            correctAnswerOverride: widget.correctAnswerOverride != null ? getStep3Answer() : null,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect, try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = FontScope.of(context);
  final hcBg = prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white;
    return Scaffold(
  appBar: AppBar(
    title: const Text('Step Two'),
    backgroundColor: const Color.fromRGBO(236, 229, 243, 1),
    actions: const [GlobalA11yActions()], // ← ADDED
  ),
  body: Container(
    color: hcBg,                            // ← ADDED
    child: Center(

        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
  const Text(
    'Step two:',
    style: TextStyle(fontSize: 20),
  ),
  const SizedBox(height: 12),

  // ▼▼ ADDED PREVIEW
  const Text('Current', style: TextStyle(fontSize: 14, color: Colors.black54)),
  MathPreviewBox(eq: widget.equation, fontSize: 22),
  const SizedBox(height: 12),
  // ▲▲ ADDED PREVIEW

  findComponents(context, widget.equation)
,

              const SizedBox(height: 10),
const LegendBar(),
InstructionBanner(
  title: 'What to do',
  bullets: [
    'Add the blue numbers on the LEFT (x-coefficients).',
    'Subtract the blue numbers on the RIGHT.',
    'Type the result (this is the BLUE total a).',
  ],
),
ExampleCard(
  caption: 'Example',
  body: RichText(
    text: const TextSpan(
      style: TextStyle(fontSize: 18, color: Colors.black),
      children: [
        TextSpan(text: '2x', style: TextStyle(color: Colors.blue)),
        TextSpan(text: '  +  7  =  '),
        TextSpan(text: 'x', style: TextStyle(color: Colors.blue)),
        TextSpan(text: '  +  9   →   '),
        TextSpan(text: '2', style: TextStyle(color: Colors.blue)),
        TextSpan(text: '  −  '),
        TextSpan(text: '1', style: TextStyle(color: Colors.blue)),
        TextSpan(text: '  =  1'),
      ],
    ),
  ),
),

              const SizedBox(height: 20),
              const Text(
                'Add all the blue numbers on the left side together. Then subtract the blue numbers on the right side from that sum.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Text(
                buildStep2Equation(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _answerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '?',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: checkAnswer,
                child: const Text('Check Answer'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class StepThreePage extends StatefulWidget {
  final String equation;
  final int? correctAnswerOverride;
  const StepThreePage({super.key, required this.equation, this.correctAnswerOverride});
  @override
  State<StepThreePage> createState() => _StepThreePageState();
}

class _StepThreePageState extends State<StepThreePage> {
  final TextEditingController _answerController = TextEditingController();
  int correctAnswer = 0;
  // added controllers for fraction input
  final TextEditingController _numCtl = TextEditingController();
  final TextEditingController _denCtl = TextEditingController();
  final TextEditingController _decCtl = TextEditingController(); // optional decimal

  int getSum(List<String> values) {
    return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
  }

  @override
void initState() {
  super.initState();
  final ab = computeAB(widget.equation);
  final a = ab.a, b = ab.b;

  final status = solutionStatus(b, a);
  if (status.isNotEmpty) {
    correctAnswer = 0;
    _answerController.text = '';
    return;
  }

  final frac = renderQuotient(b, a);
  if (frac.isInteger) {
    correctAnswer = frac.intValue!;
    if (widget.correctAnswerOverride != null) {
      _answerController.text = correctAnswer.toString();
    }
  } else {
    correctAnswer = 0;
    _answerController.text = '';
  }
}




  String buildStep3Equation() {
  final b = getSum(constantsrightValues) - getSum(constantsleftValues);
  final a = getSum(xvalleftValues) - getSum(xvalrightValues);
  final status = solutionStatus(b, a);
  if (status.isNotEmpty) return '$b / $a = ?';

  final frac = renderQuotient(b, a);
  return '$b / $a = ${frac.text.isEmpty ? "?" : frac.text}';
}


  void checkAnswer() {
  int? userAnswer = int.tryParse(_answerController.text);
  if (userAnswer != null && userAnswer == correctAnswer) {
    final box = Hive.box<SolvedProblem>('solved_problems');
    final problem = SolvedProblem(
      equation: widget.equation,
      step1Answer: getSum(constantsrightValues) - getSum(constantsleftValues),
      step2Answer: getSum(xvalleftValues) - getSum(xvalrightValues),
      finalAnswer: correctAnswer,   // integer result
      solvedAt: DateTime.now(),
      finalAnswerText: null,        // <- important: keep null for integers
    );

    // dedupe: same equation AND same integer answer
    final alreadyExists = box.values.any((p) =>
      p.equation == problem.equation &&
      p.finalAnswer == problem.finalAnswer &&
      (p.finalAnswerText ?? '') == (problem.finalAnswerText ?? '')
    );

    if (!alreadyExists) {
      box.add(problem);
    }

    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FinalAnswerPage(
      equation: widget.equation,        // ← ADDED
      finalAnswer: correctAnswer,
    ),
  ),
);

  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incorrect, try again.')),
    );
  }
}

     void _checkFractionAnswer() {
  final b = getSum(constantsrightValues) - getSum(constantsleftValues); // orange
  final a = getSum(xvalleftValues) - getSum(xvalrightValues);           // blue
  if (a == 0) return;

  final target = _reduced(b, a);
  final tn = target[0], td = target[1];

  final inNum = _safeParseInt(_numCtl.text);
  final inDen = _safeParseInt(_denCtl.text);

  final isFracGood = (inDen != 0) && _fractionsEqual(inNum, inDen, tn, td);
  final isDecGood  = _decimalMatchesFraction(_decCtl.text, tn, td);

  if (isFracGood || isDecGood) {
    final display = '$tn/$td (= ${(b / a).toStringAsFixed(3)})';

    // SAVE to Hive (fraction path)
    final box = Hive.box<SolvedProblem>('solved_problems');
    final problem = SolvedProblem(
  equation: widget.equation,
  step1Answer: b,
  step2Answer: a,
  finalAnswer: 0,             // ← use 0 instead of null
  solvedAt: DateTime.now(),
  finalAnswerText: display,   // ← "n/d (= 0.xxx)"
);


    // dedupe: same equation AND same text answer
    final exists = box.values.any((p) =>
      p.equation == problem.equation &&
      (p.finalAnswer ?? -999999) == (problem.finalAnswer ?? -999999) &&
      (p.finalAnswerText ?? '') == (problem.finalAnswerText ?? '')
    );

    if (!exists) box.add(problem);

    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => FinalAnswerPage(
      equation: widget.equation,        // ← ADDED
      finalAnswerText: display,
    ),
  ),
);

  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not quite—try simplifying the fraction.')),
    );
  }
}




  @override
  
Widget build(BuildContext context) {
  // ▼ ADD
  final prefs = FontScope.of(context);
  final hcBg = prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white;

  // Compute b (orange) and a (blue)

  final b = getSum(constantsrightValues) - getSum(constantsleftValues);
  final a = getSum(xvalleftValues) - getSum(xvalrightValues);

  // Check special cases and fraction/int mode
  final status = solutionStatus(b, a);      // "No solution" / "Infinitely many solutions" / ""
  final frac = renderQuotient(b, a);        // from step (3), shows simplified fraction or integer

 return Scaffold(
  appBar: AppBar(
    title: const Text('Step Three'),
    backgroundColor: const Color.fromRGBO(236, 229, 243, 1),
    actions: const [GlobalA11yActions()], // ← ADDED
  ),
  body: Container(
    color: hcBg,                            // ← ADDED
    child: Center(

      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
  const Text(
    'Step three:',
    style: TextStyle(fontSize: 20),
  ),
  const SizedBox(height: 12),

  // ▼▼ ADDED PREVIEW
  const Text('Current', style: TextStyle(fontSize: 14, color: Colors.black54)),
  MathPreviewBox(eq: widget.equation, fontSize: 22),
  const SizedBox(height: 12),
  // ▲▲ ADDED PREVIEW

  findComponents(context, widget.equation)
,

            const SizedBox(height: 20),

            // ▼▼▼ INSERTED STATUS MESSAGE BLOCK (this is what you asked for) ▼▼▼
            if (status.isNotEmpty) ...[
              Text(
                status, // "No solution" or "Infinitely many solutions"
                style: const TextStyle(fontSize: 20, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
  '$b / $a',
  style: const TextStyle(fontSize: 18),
  textAlign: TextAlign.center,
),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              // IMPORTANT: We STOP here for special cases—nothing else below will render
            ],
            // ▲▲▲ END STATUS MESSAGE BLOCK ▲▲▲

            // Only show the normal Step 3 UI if there is no special status:
            if (status.isEmpty) ...[
              const Text(
  // Note: flipped instruction to match a·x = b (orange ÷ blue)
  'Divide the orange number by the blue number. '
  'If necessary, show the result as a simplified fraction (and decimal).',
  textAlign: TextAlign.center,
  style: TextStyle(fontSize: 15),
),
const SizedBox(height: 20),

// 👇 These are separate children of the Column (NOT inside Text)
const SizedBox(height: 10),
const LegendBar(),
InstructionBanner(
  title: 'What to do',
  bullets: [
    'Take the ORANGE total (from Step 1) and divide by the BLUE total (from Step 2).',
    'If it isn’t a whole number, enter a simplified fraction (and optional decimal).',
  ],
),
ExampleCard(
  caption: 'Visual',
  body: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      Text('orange ÷ blue  →  ', style: TextStyle(fontSize: 18)),
      Text('b', style: TextStyle(fontSize: 22, color: Color.fromARGB(255, 255, 149, 0))),
      Text('  /  ', style: TextStyle(fontSize: 18)),
      Text('a', style: TextStyle(fontSize: 22, color: Colors.blue)),
    ],
  ),
),
const SizedBox(height: 12),

// Now your equation preview
RichText(
  textAlign: TextAlign.center,
  text: TextSpan(
    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
    children: [
      TextSpan(text: '$b', style: const TextStyle(color: kOrange)),
      const TextSpan(text: ' / '),
      TextSpan(text: '$a', style: const TextStyle(color: Colors.blue)),
      // intentionally no "= …" shown here
    ],
  ),
),


const SizedBox(height: 20),

              
// INTEGER MODE (quiz input)
if (frac.isInteger) ...[
  SizedBox(
    width: 100,
    child: TextField(
      controller: _answerController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: '?',
        border: OutlineInputBorder(),
      ),
    ),
  ),
  const SizedBox(height: 20),
  ElevatedButton(
    onPressed: checkAnswer,
    child: const Text('Check Answer'),
  ),
],

              // INTEGER MODE (keep your quiz input)
              // FRACTION MODE (guided input)
if (!frac.isInteger) ...[
  const Text(
    'Enter x as a simplified fraction:',
    style: TextStyle(fontSize: 16),
    textAlign: TextAlign.center,
  ),
  const SizedBox(height: 10),

  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 90,
        child: TextField(
          controller: _numCtl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'numerator',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('—', style: TextStyle(fontSize: 28)),
      ),
      SizedBox(
        width: 90,
        child: TextField(
          controller: _denCtl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'denominator',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ],
  ),

  const SizedBox(height: 10),
  const Text(
    'Tip: reduce to lowest terms (e.g., 6/8 → 3/4).',
    style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 120, 120, 120)),
    textAlign: TextAlign.center,
  ),

  const SizedBox(height: 14),
  SizedBox(
    width: 160,
    child: TextField(
      controller: _decCtl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'or decimal (≈)',
        hintText: 'e.g., 1.5',
        border: OutlineInputBorder(),
      ),
    ),
  ),

  const SizedBox(height: 20),
  ElevatedButton(
    onPressed: _checkFractionAnswer,
    child: const Text('Check Answer'),
  ),
],


              // FRACTION MODE (no input; just continue)
              
            ],
          ],
        ),
      ),
    ),
  ));
}

}

class FinalAnswerPage extends StatelessWidget {
  final String? equation;        // ← ADDED (optional preview)
  final int? finalAnswer;        // when integer
  final String? finalAnswerText; // when fraction or special text

  const FinalAnswerPage({super.key, this.equation, this.finalAnswer, this.finalAnswerText});

  @override
  Widget build(BuildContext context) {
    final prefs = FontScope.of(context);
  final hcBg = prefs.highContrast ? const Color(0xFF0D0D0D) : Colors.white;
    final display = finalAnswerText ?? finalAnswer?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
  title: const Text('Result'),
  backgroundColor: const Color.fromRGBO(236, 229, 243, 1),
  actions: const [GlobalA11yActions()], // ← ADDED
  // keep your home icon & leading back if you like (you already have them)
  actionsIconTheme: const IconThemeData(),
  // your existing actions/back buttons can remain
),

      body: Container(
  color: hcBg, // ← ADDED
  child: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (equation != null) ...[
          const Text('Original equation', style: TextStyle(fontSize: 14, color: Colors.black54)),
          MathPreviewBox(eq: equation!, fontSize: 22),
          const SizedBox(height: 16),
        ],
        Text(
          'Correct, the answer is $display',

              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Big “Back to Home” button
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),

            const SizedBox(height: 8),

            // Optional: a simple “Back” to the previous step
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    ));
  }
}

