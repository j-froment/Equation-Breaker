import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/solvedproblem.dart';
import 'package:flutter/services.dart';
// Importing the necessary packages for the OCR which are taken from https://pub.dev/packages/google_mlkit_text_recognition
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      title: 'Dycalculating equations',
      home: 
      //Scaffold(body: Center(child: Text('Hello World')))
       const TextBoxExample(),
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

/// Parses an algebraic equation to identify x terms and constants on both sides.
/// It also colors x terms as blue and constants as orange.
/// @param equation The input algebraic equation as a string.
Widget findComponents(String equation) {
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

  List<InlineSpan> spans = [];
  int rawIndex = 0;
  for (int idx = 0; idx < formattedEquation.length; idx++) {
    String char = formattedEquation[idx];
    if (char == ' ') {
      spans.add(const TextSpan(text: ' '));
      continue;
    }
    TextStyle style = const TextStyle(color: Colors.black);
    if (rawIndex < left.length) {
      if (xvalleft.contains(rawIndex)) {
        style = const TextStyle(color: Colors.blue);
      } else if (constantsleft.contains(rawIndex)) {
        style = const TextStyle(color: Color.fromARGB(255, 255, 149, 0));
      }
    } else if (rawIndex == left.length) {
      style = const TextStyle(color: Colors.black);
    } else {
      int rightIndex = rawIndex - (left.length + 1);
      if (xvalright.contains(rightIndex)) {
        style = const TextStyle(color: Colors.blue);
      } else if (constantsright.contains(rightIndex)) {
        style = const TextStyle(color: Color.fromARGB(255, 255, 149, 0));
      }
    }
    spans.add(TextSpan(text: char, style: style));
    rawIndex++;
  }
  return RichText(
    text: TextSpan(children: spans, style: const TextStyle(fontSize: 24)),
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
      if (i == 0 ||
          !(isInteger(equation[i - 1]) || equation[i - 1].endsWith('x'))) {
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
      } else if (val.endsWith('x')) {
        String coef = val.replaceAll('x', '');
        if (coef == '') coef = '1';
        if (coef == '-') coef = '-1';
        int value = int.parse(coef);
        distributed.add('${value * mult}x');
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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  File? selectedMedia;
  String extractedText = "";
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

  Future<void> _openOCRScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OCRScanner()),
    );
    if (result is String && result.isNotEmpty) {
      setState(() {
        _controller.text = result;
      });
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void _goToNewPage() {
  final rawInput = _controller.text;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PrepPage(rawInput: rawInput)),
  ).then((_) => loadHistory());
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter a linear equation using only whole-number values'),
        backgroundColor: Color.fromRGBO(236,229,243,1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type equation here:',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openOCRScanner,
              child: const Text('Pick Image from Gallery'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _goToNewPage,
              child: const Text('Enter'),
            ),
            const SizedBox(height: 20),
            if (selectedMedia != null) ...[
              Image.file(selectedMedia!, width: 200),
              const SizedBox(height: 10),
              Text(
                extractedText.isEmpty ? "Extracting text..." : "Detected: $extractedText",
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 30),
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
                      Text("Answer = ${problem.finalAnswer}", style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 158, 158, 158))),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEquation = value;
                });
                final selectedProblem = history.firstWhere((p) => p.equation == value);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EquationPage(
                      equation: selectedProblem.equation,
                      correctAnswerOverride: selectedProblem.step1Answer,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
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
                      Text("Answer = ${problem.finalAnswer}", style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 230, 8, 8))),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEquationToDelete = value;
                });
              },
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

  List<int> _scanDenoms(String s) {
    final r = RegExp(r'/\s*([0-9]+)');
    return r.allMatches(s).map((m) => int.tryParse(m.group(1)!) ?? 1).where((x) => x > 1).toList();
  }

  int _lcmAll(Iterable<int> xs) {
    int res = 1;
    for (final v in xs) {
      res = lcm(res, v);
    }
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
    super.dispose();
  }

 void _applyLCM() {
  final k = int.tryParse(_lcmCtl.text);
  if (k == null || k <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a positive LCM.')),
    );
    return;
  }

  try {
    // Build the raw "k(left)=k(right)" line you expect after multiplying.
    final multiplied = _mulBothSides(widget.working, k); // e.g., 12(x/3)=12(5/4)

    final typedCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Type the equation after clearing fractions'),
        content: TextField(
          controller: typedCtl,
          decoration: const InputDecoration(
            hintText: 'e.g., 3(x+3)=4(2x-1)',
          ),
          minLines: 1, maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final typed = typedCtl.text.trim();

              // Must be equivalent to the ×LCM line (order/spacing/parentheses can differ)
              bool sameAsMultiplied;
try {
  sameAsMultiplied = canonicalizeEquation(typed) == canonicalizeEquation(multiplied);
} catch (_) {
  sameAsMultiplied = false;
}


              // Fractions must be gone now (no slashes anywhere)
              final noFractions = !_hasSlash(typed);

              if (sameAsMultiplied && noFractions) {
                // Accept Step A. Keep their parentheses so Step B can ask to distribute.
                widget.onApplied(typed);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Great — fractions cleared. Now distribute parentheses.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Make sure your line matches after ×LCM and has no fractions (slashes).'),
                  ),
                );
              }
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Couldn’t clear: $e')),
    );
  }
}




  @override
  Widget build(BuildContext context) {
    final denoms = _scanDenoms(widget.working);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step A — Clear Fractions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (denoms.isNotEmpty) Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text('Denominators seen:'),
                ...denoms.map((d) => Chip(label: Text(d.toString()))),
              ],
            ) else const Text('No denominators detected.'),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _lcmCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'LCM', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _applyLCM, child: const Text('Apply ×LCM')),
              ],
            ),
            const SizedBox(height: 8),
            const Text('This will multiply both sides by LCM and simplify automatically (no need to retype k(…)=k(…)).'),
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

  @override
  void dispose() {
    _typedCtl.dispose();
    super.dispose();
  }

  void _check() {
    final typed = _typedCtl.text.trim();
    if (typed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type your distributed line.')));
      return;
    }
    // Must be equivalent AND reduce (or keep, not increase) parentheses count
    final eqOK = _eqCanon(typed, widget.working);
    final before = RegExp(r'\(').allMatches(widget.working).length;
    final after  = RegExp(r'\(').allMatches(typed).length;

    if (eqOK && after <= before) {
      widget.onDistributed(typed);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Good distribution step!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not quite—distribute again or check signs.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step B — Distribute Parentheses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Expand k( … ) → k·… and simplify.'),
            const SizedBox(height: 10),
            TextField(
              controller: _typedCtl,
              minLines: 1, maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your next line after distributing',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(onPressed: _check, child: const Text('Check distribution')),
                const SizedBox(width: 12),
                Text('Start:  ${' ' + widget.working}', style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
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
  late String working; // student’s current equation string


  bool needFractions = false;
  bool needParens = false;

  @override
  void initState() {
    super.initState();
    working = widget.rawInput.trim();
    needFractions = _hasSlash(working);
    needParens = _hasParens(working);
  }

  void _gotoStep1() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EquationPage(equation: working)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prep: you do the setup'),
        backgroundColor: Color.fromRGBO(236,229,243,1),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Start from your equation. Do each move yourself; I’ll just check it.'),
          const SizedBox(height: 8),
          Text('Current:  $working', style: const TextStyle(fontSize: 18)),

          // ---- Step A: Clear Fractions ----
          if (needFractions) ...[
  PrepLCMCard(
    working: working,
    onApplied: (newWorking) {
      setState(() {
        working = newWorking;
        // keep your existing flags in sync with the step’s result
        needFractions = _hasSlash(working); // may still be true if user kept fractions
        needParens   = _hasParens(working);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nice! Fractions step accepted.')),
      );
    },
  ),
],


          // ---- Step B: Distribute Parentheses ----
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
              _gotoStep1();
            },
            child: const Text('I’m ready for Step 1'),
          ),
        ],
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
    findComponents(widget.equation);
    int rightSum = getSum(constantsrightValues);
    int leftSum = getSum(constantsleftValues);
    correctAnswer = widget.correctAnswerOverride ?? (rightSum - leftSum);

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
    String breakdown = constantsrightValues.join(' + ');
    if (constantsleftValues.isNotEmpty) {
      for (var val in constantsleftValues) {
        breakdown += ' - $val';
      }
    }
    breakdown += ' = ';

    return Scaffold(
      appBar: AppBar(title: const Text("Step One"),
        backgroundColor: Color.fromRGBO(236,229,243,1)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Step one:',
                style: TextStyle(fontSize: 20),
              ),
              findComponents(widget.equation),
              const SizedBox(height: 20),
              const Text(
                'Add all the orange numbers on the right side together. Then subtract the orange numbers on the left side from that sum.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Text(
                breakdown,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 149, 0)),
              ),
              const SizedBox(height: 10),
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
    findComponents(widget.equation);
    int leftSum = getSum(xvalleftValues);
    int rightSum = getSum(xvalrightValues);
    correctAnswer = widget.correctAnswerOverride ?? (leftSum - rightSum);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Two'),
        backgroundColor: Color.fromRGBO(236, 229, 243, 1),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Step two:',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              findComponents(widget.equation),
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
    );
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
  findComponents(widget.equation);

  final b = getSum(constantsrightValues) - getSum(constantsleftValues); // orange
  final a = getSum(xvalleftValues) - getSum(xvalrightValues);           // blue

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
    // fraction mode: no input in this step
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
        finalAnswer: correctAnswer,
        solvedAt: DateTime.now(),
      );
      // Check for duplicate before adding
    final alreadyExists = box.values.any((p) =>
      p.equation == widget.equation &&
      p.finalAnswer == correctAnswer
    );

    if (!alreadyExists) {
      box.add(problem);
    }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinalAnswerPage(finalAnswer: correctAnswer),
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FinalAnswerPage(
            finalAnswerText: '$tn/$td (= ${(b / a).toStringAsFixed(3)})',
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
  // Compute b (orange) and a (blue)
  final b = getSum(constantsrightValues) - getSum(constantsleftValues);
  final a = getSum(xvalleftValues) - getSum(xvalrightValues);

  // Check special cases and fraction/int mode
  final status = solutionStatus(b, a);      // "No solution" / "Infinitely many solutions" / ""
  final frac = renderQuotient(b, a);        // from step (3), shows simplified fraction or integer

  return Scaffold(
    appBar: AppBar(
      title: const Text('Step Three'),
      backgroundColor: Color.fromRGBO(236, 229, 243, 1),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Step three:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            findComponents(widget.equation),
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
              Text(
                // Shows "b / a = <fraction or integer or ?>"
                buildStep3Equation(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
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
  );
}

}

class FinalAnswerPage extends StatelessWidget {
  final int? finalAnswer;        // when integer
  final String? finalAnswerText; // when fraction or special text

  const FinalAnswerPage({super.key, this.finalAnswer, this.finalAnswerText});

  @override
  Widget build(BuildContext context) {
    final display = finalAnswerText ?? finalAnswer?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        backgroundColor: Color.fromRGBO(236, 229, 243, 1),
      ),
      body: Center(
        child: Text(
          'Correct, the answer is $display',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
