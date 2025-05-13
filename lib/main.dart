import 'dart:io';
import 'package:flutter/material.dart';



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


void main() {
 runApp(const MyApp());
}




/// findComponents - Parses an algebraic equation to identify x terms and constants on both sides.
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


// Loop that scans the 'equation' string to find the first '=' character.
// Once found, it splits the equation into two parts:
// 'left' contains the substring before the '=', and
// 'right' contains the substring after the '='.
  for (var i = 0; i < equation.length; i++) {
    if (equation[i] == '=') {
      left = equation.substring(0, i);
      right = equation.substring(i + 1);
      break;
    }
  }


  // LEFT SIDE
// This loop iterates through the left side of the equation (before '=').
// It identifies constants and variable terms (i.e., "3", "-2x", "x") using helper functions:
// - isNumeric(): checks if a character is a digit
// - isLetter(): checks if a character is a letter
// It stores the indices of the constants and variables in 'constantsleft' and 'xvalleft', respectively.
// Their string values are stored in 'constantsleftValues' and 'xvalleftValues'.
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
// This loop iterates through the right side of the equation (before '=').
// It identifies constants and variable terms (i.e., "3", "-2x", "x") using helper functions:
// - isNumeric(): checks if a character is a digit
// - isLetter(): checks if a character is a letter
// It stores the indices of the constants and variables in 'constantsright' and 'xvalright', respectively.
// Their string values are stored in 'constantsrightValues' and 'xvalrightValues'.
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


  // === FORMAT EQUATION WITH TERM SPACING ===
// This part formats the 'raw' equation string by adding spacing around operators
// like '+', '-', and '=' to improve readability. It also groups numbers and variables
// together as individual terms (e.g., "5x" or "10") so they are treated as units.
  String formattedEquation = '';
  final buffer = StringBuffer();


  int k = 0;
  while (k < equation.length) {
    String char = equation[k];


    if (char == '+' || char == '-' || char == '=' ) {
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


  // === COLORING BASED ON ORIGINAL INDEX ===
  // Builds a styled version of the formatted equation by assigning colors
// to variables (x terms) and constants based on their positions in the original equation.
// It creates a List of TextSpan objects for syntax-style highlighting.

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
      // '=' character
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
/// to improve readability and separate terms like "5x" or "10".
/// @param eq The 'raw' equation string to format.
/// @return A string with spaces added between terms and operators.
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
      while (i < eq.length &&
          eq[i] != '+' &&
          eq[i] != '-' &&
          eq[i] != '=') {
        term += eq[i];
        i++;
      }
      result += term;
    }
  }


  return result.trim();
}





/// Checks if the given string is a valid number (integer or decimal)
/// @param s The string to evaluate.
/// @return True if the string can be parsed as a number, false otherwise.
bool isNumeric(String s) {
 return double.tryParse(s) != null;
}



/// Checks if a single-character string is a letter (A-Z or a-z) using ASCII values.
/// @param s The character to evaluate (should be length 1).
/// @return True if the character is a letter, false otherwise.
bool isLetter(String s) {
 if (s.length != 1) return false;
 int codeUnit = s.codeUnitAt(0);
 return (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
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
     home: const TextBoxExample(),
   );
 }
}




class TextBoxExample extends StatefulWidget {
 const TextBoxExample({super.key});




 @override
 State<TextBoxExample> createState() => _TextBoxExampleState();
}




class _TextBoxExampleState extends State<TextBoxExample> {
 final TextEditingController _controller = TextEditingController();
 File? selectedMedia;
 String extractedText = "";




 void _goToNewPage() {
   String equation = _controller.text;
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => EquationPage(equation: equation),
     ),
   );
 }




 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Text('Enter Your Equation (only supports interger values):'),
             backgroundColor: Color.fromRGBO(236,229,243,1)),


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
         ],
       ),
     ),
   );
 }
}




class EquationPage extends StatefulWidget {
 final String equation;




 const EquationPage({super.key, required this.equation});




 @override
 State<EquationPage> createState() => _EquationPageState();
}




class _EquationPageState extends State<EquationPage> {
 final TextEditingController _answerController = TextEditingController();
 int correctAnswer = 0;



// Function to calculate the sum of the constants on both sides of the equation
// @parameter values - list of string values to be summed
// @return the sum of the values in the list
 int getSum(List<String> values) {
   return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
 }



/// Initializes the state of the widget and computes the correct answer
/// by extracting and summing constants from both sides of the equation.
/// The difference (rightSum - leftSum) is stored as the correct answer
/// to be used for answer validation later.
 @override
 void initState() {
   super.initState();
   findComponents(widget.equation);




   int rightSum = getSum(constantsrightValues);
   int leftSum = getSum(constantsleftValues);
   correctAnswer = rightSum - leftSum;
 }



/// Checks the user's submitted answer against the correct value.
/// @param _answerController.text - the text input from the user.
/// If correct, navigates to StepTwoPage. If incorrect, displays
/// a SnackBar message prompting the user to try again.
 void checkAnswer() {
   int? userAnswer = int.tryParse(_answerController.text);
   if (userAnswer != null && userAnswer == correctAnswer) {
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => StepTwoPage(equation: widget.equation),
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


  const StepTwoPage({super.key, required this.equation});


  @override
  State<StepTwoPage> createState() => _StepTwoPageState();
}


class _StepTwoPageState extends State<StepTwoPage> {
  final TextEditingController _answerController = TextEditingController();
  int correctAnswer = 0;


  int getSum(List<String> values) {
    return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
  }


  @override
  void initState() {
    super.initState();
    findComponents(widget.equation);


  int leftSum = getSum(xvalleftValues);
int rightSum = getSum(xvalrightValues);
correctAnswer = leftSum - rightSum;


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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correct! ')),
      );
      
    }if (userAnswer != null && userAnswer == correctAnswer) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StepThreePage(equation: widget.equation),
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
                'Correct!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
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
  const StepThreePage({super.key, required this.equation});


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


  // Step 1: constants sum
  int step1Right = getSum(constantsrightValues);
  int step1Left = getSum(constantsleftValues);
  int step1Result = step1Right - step1Left;


  // Step 2: x coefficient sum
  int step2Left = getSum(xvalleftValues);
  int step2Right = getSum(xvalrightValues);
  int step2Result = step2Left - step2Right;


  if (step2Result != 0) {
    correctAnswer = (step1Result / step2Result).round(); // rounding for integer TextField
  } else {
    correctAnswer = 0; // or handle divide-by-zero more carefully if needed
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
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FinalAnswerPage(finalAnswer: correctAnswer),
    ),
  );
}


      
     else {
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
                'Correct!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
      
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
              // Display the constants-only breakdown
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







