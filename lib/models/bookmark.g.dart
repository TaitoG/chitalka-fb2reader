// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 5;

  @override
  Bookmark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bookmark(
      id: fields[0] as String,
      bookId: fields[1] as String,
      bookTitle: fields[2] as String,
      type: fields[3] as BookmarkType,
      text: fields[4] as String,
      context: fields[5] as String?,
      translation: fields[6] as String?,
      sectionIndex: fields[7] as int,
      pageIndex: fields[8] as int,
      createdAt: fields[9] as DateTime,
      lastReviewedAt: fields[10] as DateTime?,
      reviewCount: fields[11] as int,
      notes: fields[12] as String?,
      tags: (fields[13] as List).cast<String>(),
      isFavorite: fields[14] as bool,
      currentRepetition: fields[15] as int,
      totalCorrectCount: fields[16] as int,
      nextReviewDate: fields[17] as DateTime?,
      intervalDays: fields[18] as int,
      masteryLevel: fields[19] as int,
      progressPercent: fields[20] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.bookTitle)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.context)
      ..writeByte(6)
      ..write(obj.translation)
      ..writeByte(7)
      ..write(obj.sectionIndex)
      ..writeByte(8)
      ..write(obj.pageIndex)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastReviewedAt)
      ..writeByte(11)
      ..write(obj.reviewCount)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.tags)
      ..writeByte(14)
      ..write(obj.isFavorite)
      ..writeByte(15)
      ..write(obj.currentRepetition)
      ..writeByte(16)
      ..write(obj.totalCorrectCount)
      ..writeByte(17)
      ..write(obj.nextReviewDate)
      ..writeByte(18)
      ..write(obj.intervalDays)
      ..writeByte(19)
      ..write(obj.masteryLevel)
      ..writeByte(20)
      ..write(obj.progressPercent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
