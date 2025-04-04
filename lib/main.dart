import 'package:flutter/material.dart';
 

void main() {
  //global variable declarations

  runApp(const MyApp());
}

void_findThings() {
  //function to find the variables in the equation
   var equation = '6x + 5x = -11';
 var x;
var y;
var solution;
 for (var i = 0; i < equation.length; i++) {
   if (isNumeric(equation[i])) {
     x = equation[i];
   
 } 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Box Demo',
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
  String _displayText = '';


  void _updateText() {
    setState(() {
      _displayText = _controller.text;
    });
  }


  void _updatePicture() {
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Your Equation:')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type equation here: ',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateText,
              child: const Text('Enter'),
            ),
            const SizedBox(height: 20),
            Text(
              _displayText,
              style: const TextStyle(fontSize: 18),
            ),
             const SizedBox(height: 20),
            Text(
              'Or',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 40, width: 50),
            ElevatedButton(
              onPressed: _updatePicture,
              child: const Text('Upload picture of equation here'),
            ),
          ],
        ),
      ),
    );
  }
}



