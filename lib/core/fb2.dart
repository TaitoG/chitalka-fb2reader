// fb2.dart
import 'package:xml/xml.dart';
import 'package:chitalka/models/book.dart';

class Fb2Parse {
  static Book parse(String fb2Content) {
    final document = XmlDocument.parse(fb2Content);
    final fiction = document.findAllElements('FictionBook').first;
    final description = fiction.findElements('description').first;
    final titleInfo = description.findElements('title-info').first;

    final title = titleInfo.findElements('book-title').first.innerText;

    final author = titleInfo.findElements('author').map((author) {
      final fName = author.findElements('first-name').firstOrNull?.innerText ?? '';
      final lName = author.findElements('last-name').firstOrNull?.innerText ?? '';
      final mName = author.findElements('middle-name').firstOrNull?.innerText ?? '';
      return '$fName ${mName.isNotEmpty ? '$mName ' : ''}$lName'.trim();
    }).toList();

    final annotation = titleInfo.findElements('annotation').firstOrNull?.innerText ?? '';

    final coverImageId = titleInfo.findElements('coverpage').firstOrNull
        ?.findElements('image').firstOrNull
        ?.getAttribute('l:href')
        ?.replaceFirst('#', '');

    final binaries = extractBinaries(fb2Content);

    String? coverImageData;
    if (coverImageId != null && binaries.containsKey(coverImageId)) {
      coverImageData = binaries[coverImageId];
    }

    final body = fiction.findElements('body').first;
    final sections = _parseSections(body);

    return Book(
        title: title,
        author: author,
        annotation: annotation,
        coverImage: coverImageData,
        sections: sections,
        content: fb2Content
    );
  }

  static List<BookSection> _parseSections(XmlElement parent) {
    final sections = <BookSection>[];
    for (final element in parent.childElements) {
      if (element.name.local == 'section') {
        final title = element.findElements('title').firstOrNull?.innerText ?? '';
        final paragraphs = element.findElements('p').map((p) => p.innerText).toList();
        final subsections = _parseSections(element);

        if (paragraphs.isEmpty && subsections.isNotEmpty) {
          sections.addAll(subsections);
        } else if (paragraphs.isNotEmpty || subsections.isNotEmpty) {
          sections.add(BookSection(
              title: title,
              paragraphs: paragraphs,
              subsections: subsections
          ));
        }
      }
    }
    return sections;
  }

  static Map<String, String> extractBinaries(String fb2Content) {
    final doc = XmlDocument.parse(fb2Content);
    final bins = <String, String>{};

    for (final bin in doc.findAllElements('binary')) {
      final id = bin.getAttribute('id');
      final data = bin.innerText;

      if (id != null && data.isNotEmpty) {
        final cleanedData = data.replaceAll(RegExp(r'\s+'), '');
        bins[id] = cleanedData;
      }
    }

    return bins;
  }
}