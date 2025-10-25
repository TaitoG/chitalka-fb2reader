// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pagination_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaginationCacheAdapter extends TypeAdapter<PaginationCache> {
  @override
  final int typeId = 1;

  @override
  PaginationCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaginationCache(
      bookFilePath: fields[0] as String,
      fontSize: fields[1] as double,
      lineHeight: fields[2] as double,
      screenWidth: fields[3] as double,
      screenHeight: fields[4] as double,
      sections: (fields[5] as Map).cast<int, SectionPaginationData>(),
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PaginationCache obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.bookFilePath)
      ..writeByte(1)
      ..write(obj.fontSize)
      ..writeByte(2)
      ..write(obj.lineHeight)
      ..writeByte(3)
      ..write(obj.screenWidth)
      ..writeByte(4)
      ..write(obj.screenHeight)
      ..writeByte(5)
      ..write(obj.sections)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SectionPaginationDataAdapter extends TypeAdapter<SectionPaginationData> {
  @override
  final int typeId = 2;

  @override
  SectionPaginationData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SectionPaginationData(
      sectionIndex: fields[0] as int,
      pages: (fields[1] as List).cast<PageTokenData>(),
    );
  }

  @override
  void write(BinaryWriter writer, SectionPaginationData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.sectionIndex)
      ..writeByte(1)
      ..write(obj.pages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionPaginationDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PageTokenDataAdapter extends TypeAdapter<PageTokenData> {
  @override
  final int typeId = 3;

  @override
  PageTokenData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PageTokenData(
      text: fields[0] as String,
      tokens: (fields[1] as List).cast<TokenData>(),
    );
  }

  @override
  void write(BinaryWriter writer, PageTokenData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.tokens);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageTokenDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TokenDataAdapter extends TypeAdapter<TokenData> {
  @override
  final int typeId = 4;

  @override
  TokenData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenData(
      text: fields[0] as String,
      word: fields[1] as String,
      startOffset: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TokenData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.word)
      ..writeByte(2)
      ..write(obj.startOffset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
