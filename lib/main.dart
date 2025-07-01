import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/solvedproblem.dart';

// Global Lists to store character indices of x terms and constants on each side
List<int> xvalleft = [];
List<int> constantsleft = [];
List<int> xvalright = [];
List<int> constantsright = [];

// Global Lists to store string representations of extracted x terms and constants
List<String> constantsleftValues = [];
List<String> constantsrightValues = [];
List<String> xvalleftValues = [];
List<String> xvalrightValues = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  //final appDocumentDir = await getApplicationDocumentsDirectory();
 // Hive.init(appDocumentDir.path);
  Hive.registerAdapter(SolvedProblemAdapter());
  await Hive.openBox<SolvedProblem>('solved_problems');
  runApp(const MyApp());
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

// =================== Utility Functions ===================

/// Parses an algebraic equation to identify x terms and constants on both sides.
/// It also colors x terms as blue and constants as orange.
/// @param equation The input algebraic equation as a string.
/// @return A RichText widget displaying the formatted equation.
Widget findComponents(String equation) {
  xvalleft.clear();
  constantsleft.clear();
  xvalright.clear();
  constantsright.clear();
  constantsleftValues.clear();
  constantsrightValues.clear();
  xvalleftValues.clear();
  xvalrightValues.clear();

  // Remove whitespace and split the equation into left and right sides
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

  // LEFT SIDE
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

  // RIGHT SIDE
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

  // Format equation with term spacing
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

  // Coloring based on original index
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

/// Adds spacing around operators (+, -, =) in an equation string
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

  // Handle parentheses and distribute multipliers
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

  // Distribute inside parentheses
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

/// Checks if the given string is a valid number (integer or decimal)
bool isNumeric(String s) {
  return double.tryParse(s) != null;
}

/// Checks if a single-character string is a letter (A-Z or a-z) using ASCII values.
bool isLetter(String s) {
  if (s.length != 1) return false;
  int codeUnit = s.codeUnitAt(0);
  return (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
}

// =================== TextBoxExample ===================
class TextBoxExample extends StatefulWidget {
  const TextBoxExample({super.key});
  @override
  State<TextBoxExample> createState() => _TextBoxExampleState();
}

class _TextBoxExampleState extends State<TextBoxExample> {
  final TextEditingController _controller = TextEditingController();
  File? selectedMedia;
  String extractedText = "";
  List<SolvedProblem> history = [];

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

  void _goToNewPage() {
    //String equation = _controller.text;
    String rawInput = _controller.text;
String equation = simplifySigns(simplifyEquation(simplifyMultiplication(rawInput)));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquationPage(equation: equation),
      ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type equation here:',
              ),
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
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text("No problems solved yet."))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final problem = history[index];
                        return ListTile(
                          title: Text(problem.equation),
                          subtitle: Text("x = ${problem.finalAnswer}"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                EquationPage(equation: problem.equation,
        correctAnswerOverride: problem.step1Answer, 
      ),
                              
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== EquationPage ===================
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

// =================== StepTwoPage ===================
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

  // Helper to compute step 3 answer
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

// =================== StepThreePage ===================
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

  int getSum(List<String> values) {
    return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
  }

  @override
  void initState() {
    super.initState();
    findComponents(widget.equation);

    int step1Right = getSum(constantsrightValues);
    int step1Left = getSum(constantsleftValues);
    int step1Result = step1Right - step1Left;

    int step2Left = getSum(xvalleftValues);
    int step2Right = getSum(xvalrightValues);
    int step2Result = step2Left - step2Right;

    if (step2Result != 0) {
      correctAnswer = (step1Result / step2Result).round();
    } else {
      correctAnswer = 0;
    }
    if (widget.correctAnswerOverride != null) {
      _answerController.text = correctAnswer.toString();
    }
  }

  String buildStep3Equation() {
    int step1Right = getSum(constantsrightValues);
    int step1Left = getSum(constantsleftValues);
    int step1Result = step1Right - step1Left;

    int step2Left = getSum(xvalleftValues);
    int step2Right = getSum(xvalrightValues);
    int step2Result = step2Left - step2Right;

    return '$step1Result / $step2Result = ?';
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
      box.add(problem);
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

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Divide the blue number by the orange number. If necessary round to the nearest integer. The result is the value of x.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Text(
                buildStep3Equation(),
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

// =================== FinalAnswerPage ===================
class FinalAnswerPage extends StatelessWidget {
  final int finalAnswer;
  const FinalAnswerPage({super.key, required this.finalAnswer});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        backgroundColor: Color.fromRGBO(236, 229, 243, 1),
      ),
      body: Center(
        child: Text(
          'Correct, the answer is $finalAnswer',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}