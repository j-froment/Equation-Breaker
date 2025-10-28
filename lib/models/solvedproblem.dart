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

  // was: int finalAnswer;
  // make it nullable so non-integer results are allowed.
  @HiveField(3)
  int? finalAnswer;

  @HiveField(4)
  DateTime solvedAt;

  // NEW: pretty string like "3/5 (= 0.600)". Leave old fields alone.
  @HiveField(5)
  String? finalAnswerText;

  SolvedProblem({
    required this.equation,
    required this.step1Answer,
    required this.step2Answer,
    this.finalAnswer,
    required this.solvedAt,
    this.finalAnswerText,
  });
}
