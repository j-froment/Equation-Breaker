import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_picker/gallery_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

  List<int> xvalleft = [];
  List<int> constantsleft = [];
  List<int> xvalright = [];
  List<int> constantsright = [];
void main() {
  runApp(const MyApp());
}


Widget findThings(String equation) {
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
  return (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122); // A-Z or a-z
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 230, 249, 205),
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


  Future<void> _pickImage() async {
    List<MediaFile>? media =
        await GalleryPicker.pickMedia(context: context, singleMedia: true);
    if (media != null && media.isNotEmpty) {
      var data = await media.first.getFile();
      setState(() {
        selectedMedia = data;
      });
      _extractTextFromImage(data);
    }
  }


  Future<void> _extractTextFromImage(File file) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    textRecognizer.close();


    setState(() {
      extractedText = recognizedText.text;
      _controller.text = extractedText;
    });
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
                labelText: 'Type equation here:',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _goToNewPage,
              child: const Text('Enter'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Or',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Upload picture of equation here'),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 20),
            if (selectedMedia != null) ...[
              Image.file(selectedMedia!, width: 200),
              const SizedBox(height: 10),
              Text(
                extractedText.isEmpty
                    ? "Extracting text..."
                    : "Detected: $extractedText",
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

  int getSum(List<int> indexes, String side) {
    int sum = 0;
    String text = side == "left"
        ? widget.equation.split("=")[0]
        : widget.equation.split("=")[1];
    for (int i in indexes) {
      StringBuffer number = StringBuffer();
      // Build the number backward until you reach non-numeric
      while (i >= 0 && isNumeric(text[i])) {
        number.write(text[i]);
        i--;
      }
      // Reverse it because we added backwards
      String value = number.toString().split('').reversed.join('');
      if (value.isNotEmpty) {
        sum += int.tryParse(value) ?? 0;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    int rightSum = getSum(constantsright, "right");
    int leftSum = getSum(constantsleft, "left");
    int total = rightSum - leftSum;

    return Scaffold(
      appBar: AppBar(title: const Text("Solver")),
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
                "$rightSum - $leftSum = ",
                style: const TextStyle(fontSize: 26),
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
            ],
          ),
        ),
      ),
    );
  }
}


