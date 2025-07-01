import 'package:hive/hive.dart';

part 'solvedproblem.g.dart';

@HiveType(typeId: 0)
class SolvedProblem extends HiveObject {
  @HiveField(0)
  String equation;

  @HiveField(1)
  int step1Answer;

  @HiveField(2)
  int step2Answer;

  @HiveField(3)
  int finalAnswer;

  @HiveField(4)
  DateTime solvedAt;


  SolvedProblem({
    required this.equation,
    required this.step1Answer,
    required this.step2Answer,
    required this.finalAnswer,
    required this.solvedAt,
  });
}