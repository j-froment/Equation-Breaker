import 'dart:io';
import 'package:flutter/material.dart';


List<int> xvalleft = [];
List<int> constantsleft = [];
List<int> xvalright = [];
List<int> constantsright = [];


List<String> constantsleftValues = [];
List<String> constantsrightValues = [];


void main() {
 runApp(const MyApp());
}


Widget findThings(String equation) {
 xvalleft.clear();
 constantsleft.clear();
 xvalright.clear();
 constantsright.clear();
 constantsleftValues.clear();
 constantsrightValues.clear();


 equation = equation.replaceAll(' ', '');
 var left = "";
 var right = "";


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
     } else {
       constantsleft.addAll(addval);
       String number = addval.map((index) => left[index]).join();
       constantsleftValues.add(number);
     }
     j += check;
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
     } else {
       constantsright.addAll(addval);
       String number = addval.map((index) => right[index]).join();
       constantsrightValues.add(number);
     }
     i += check;
   } else {
     i++;
   }
 }


 List<InlineSpan> spans = [];
 for (var k = 0; k < equation.length; k++) {
   TextStyle style = const TextStyle(color: Colors.black);


   if (k < left.length) {
     if (xvalleft.contains(k)) {
       style = const TextStyle(color: Colors.blue);
     } else if (constantsleft.contains(k)) {
       style = const TextStyle(color: Color.fromARGB(255, 255, 149, 0));
     }
   } else if (k > left.length) {
     int rightIndex = k - (left.length + 1);
     if (xvalright.contains(rightIndex)) {
       style = const TextStyle(color: Colors.blue);
     } else if (constantsright.contains(rightIndex)) {
       style = const TextStyle(color: Color.fromARGB(255, 255, 149, 0));
     }
   }
   spans.add(TextSpan(text: equation[k], style: style));
 }


 return RichText(
   text: TextSpan(children: spans, style: const TextStyle(fontSize: 24)),
 );
}


bool isNumeric(String s) {
 return double.tryParse(s) != null;
}


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
       title: const Text('Enter Your Equation:'),
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


 int getSum(List<String> values) {
   return values.fold(0, (sum, val) => sum + (int.tryParse(val) ?? 0));
 }


 @override
 void initState() {
   super.initState();
   findThings(widget.equation);


   int rightSum = getSum(constantsrightValues);
   int leftSum = getSum(constantsleftValues);
   correctAnswer = rightSum - leftSum;
 }


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
             findThings(widget.equation),
             const SizedBox(height: 40),
             const Text(
               'Step one:',
               style: TextStyle(fontSize: 20),
             ),
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


class StepTwoPage extends StatelessWidget {
 final String equation;
 const StepTwoPage({super.key, required this.equation});




 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Step Two'),
           backgroundColor: Color.fromRGBO(236,229,243,1)),

     body: Center(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Text(
               'Correct!',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
             ),
             const SizedBox(height: 20),
             const Text(
               'Step two:',
               style: TextStyle(fontSize: 20),
             ),
             const SizedBox(height: 20),
             findThings(equation),
             const Text(
               'Add all the blue numbers on the left side together. Then subtract the orange numbers on the right side from that sum. ',
               textAlign: TextAlign.center,
               style: TextStyle(fontSize: 15),
             ),
            
             const SizedBox(height: 20),
const SizedBox(height: 10),
             SizedBox(
               width: 100,
               child: TextField(
                 //controller: _answerController,
                 keyboardType: TextInputType.number,
                 decoration: const InputDecoration(
                   hintText: '?',
                   border: OutlineInputBorder(),
                 ),
               ),
             ),
             const SizedBox(height: 20),
             //ElevatedButton(
               //onPressed: checkAnswer,
               //child: const Text('Check Answer'),
            // ),         
              ],
         ),
       ),
     ),
   );
 }
 }
class StepThreePage extends StatelessWidget {
 final String equation;
 const StepThreePage({super.key, required this.equation});


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Step Two'),
           backgroundColor: Color.fromRGBO(236,229,243,1)),
     body: Center(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Text(
               'Correct!',
               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
             ),
             const SizedBox(height: 20),
             const Text(
               'Step two:',
               style: TextStyle(fontSize: 20),
             ),
             const SizedBox(height: 20),
             findThings(equation),
             const Text(
               'Add all the blue numbers on the left side together. Then subtract the orange numbers on the right side from that sum. ',
               textAlign: TextAlign.center,
               style: TextStyle(fontSize: 15),
             ),
            
             const SizedBox(height: 20),
             // You can add another input field here if you want
           ],
         ),
       ),
     ),
   );
 }
 }
