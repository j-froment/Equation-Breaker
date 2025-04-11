import 'package:flutter/material.dart';

void main() {
  //global variable declarations

  runApp(const MyApp());
}

Widget findThings(String equation) {
  var left = "";
  var right = "";

  List<int> xvalleft = [];
  List<int> constantsleft = [];
  List<int> xvalright = [];
  List<int> constantsright = [];

  for (var i = 0; i < equation.length; i++) {
    if (equation[i] == '=') {
      left = equation.substring(0, i);
      right = equation.substring(i + 1);
    }
  }

  int j = 0;
  while (j < left.length) {
    if (isNumeric(left[j])) {
      List<int> addval = [j];
      int check = 1;
      while (j + check < left.length && isNumeric(left[j + check])) {
        addval.add(j + check);
        check++;
      }

      if (j + check < left.length && left[j + check] == 'x') {
        xvalleft.addAll(addval);
      } else {
        constantsleft.addAll(addval);
      }

      j += check;
    } else {
      j++;
    }
  }

  int i = 0;
  while (i < right.length) {
    if (isNumeric(right[i])) {
      List<int> addval = [i];
      int check = 1;
      while (i + check < right.length && isNumeric(right[i + check])) {
        addval.add(i + check);
        check++;
      }

      if (i + check < right.length && right[i + check] == 'x') {
        xvalright.addAll(addval);
      } else {
        constantsright.addAll(addval);
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
    Widget? _equationWidget;



 void _updateText() {
  setState(() {
    _displayText = _controller.text;
    _equationWidget = findThings(_controller.text);
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
              'Or',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 40, width: 50),
            ElevatedButton(
              onPressed: _updatePicture,
              child: const Text('Upload picture of equation here'),
            ),
            const SizedBox(height: 20),

    if (_equationWidget != null) _equationWidget!,
          ],
        ),
      ),
    );
  }
}



