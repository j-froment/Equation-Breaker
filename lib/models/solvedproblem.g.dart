// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solvedproblem.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SolvedProblemAdapter extends TypeAdapter<SolvedProblem> {
  @override
  final int typeId = 0;

  @override
  SolvedProblem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SolvedProblem(
      equation: fields[0] as String,
      step1Answer: fields[1] as int,
      step2Answer: fields[2] as int,
      finalAnswer: fields[3] as int,
      solvedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SolvedProblem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.equation)
      ..writeByte(1)
      ..write(obj.step1Answer)
      ..writeByte(2)
      ..write(obj.step2Answer)
      ..writeByte(3)
      ..write(obj.finalAnswer)
      ..writeByte(4)
      ..write(obj.solvedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolvedProblemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
