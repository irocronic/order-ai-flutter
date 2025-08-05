// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_config.dart';

class PrinterConfigAdapter extends TypeAdapter<PrinterConfig> {
  @override
  final int typeId = 2;

  @override
  PrinterConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrinterConfig(
      name: fields[1] as String,
      ipAddress: fields[2] as String,
      port: fields[3] as int,
      type: fields[4] as String,
    )..id = fields[0] as String;
  }

  @override
  void write(BinaryWriter writer, PrinterConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ipAddress)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
