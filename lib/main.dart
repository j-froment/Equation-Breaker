import 'package:flutter/material.dart';
 

void main() {
  //global variable declarations

  runApp(const MyApp());
}

void_findThings() {
  //function to find the variables in the equation
   const equation = '6x + 5x = 11';
   var left="";
   var right ="";
  List<int> xval =[];
  
List<int> constants =[];
 for (var i = 0; i < equation.length; i++) {
   if (equation[i] == '='){
      left = equation.substring(0,i);
      right = equation.substring(i+1);
   }
 } 
 int j=0;
while(j < left.length) {
  if (isNumeric(left[j])){
    var addval = left[j];
while (true){
  int check =1;
  if (isNumeric(left[j+check])){
addval = addval + left[j+check];
check ++;
  }
else {
  var toadd = int.parse(addval);
addval="";
  if (left[j+check] == 'x'){
xval.add(toadd);
  }
  else {
    constants.add(toadd);
  }
  j+= check+1;
  break;
}
}
  }


}
 int i=0;

while(i < right.length) {
  if (isNumeric(right[i])){
    var addval = right[i];
while (true){
  int check =1;
  if (isNumeric(right[i+check])){
addval = addval + right[i+check];
check ++;
  }
else {
  var toadd = int.parse(addval);
addval="";
  if (right[i+check] == 'x'){
xval.add(toadd);
  }
  else {
    constants.add(toadd);
  }
  i+= check+1;
  break;
}
}
  }

  
}
}
bool isNumeric(String input) {
  if (int.tryParse(input) != null) {
    return true;
  } else if (double.tryParse(input) != null) {
    return true;
  } else {
return false;  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});


 @override
 Widget build(BuildContext context) {
   return MaterialApp(
     theme: ThemeData(scaffoldBackgroundColor: const Color.fromARGB(255, 230, 249, 205)),
     title: 'Dysculia Guiding App',
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



void _goToNewPage() {
   String equation = _controller.text;


   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => EquationPage(equation: equation),
     ),
   );
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
           const SizedBox(height: 40),
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


class EquationPage extends StatelessWidget {
 final String equation;


 const EquationPage({super.key, required this.equation});


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text("Your Equation")),
     body: Center(
       child: Text(
         'You entered: $equation',
         style: const TextStyle(fontSize: 24),
       ),
     ),
   );
 }
}

