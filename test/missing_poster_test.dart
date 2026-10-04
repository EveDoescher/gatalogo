import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/missing_poster.dart';
import 'package:catlogue/services/cat_sharing_service.dart';

void main() {
  final cat = Cat(
    id: 'cat',
    captureNumber: 1,
    photoPath: 'cat.jpg',
    capturedAt: DateTime(2026),
    name: 'Lua',
    collar: 'Azul',
    microchip: '123456',
    distinguishingMarks: 'Mancha branca na pata',
  );

  test(
    'poster and external share contain the same address, traits and contacts',
    () {
      final report = <String, dynamic>{
        'last_seen_address': 'Rua das Flores, 15, Centro',
        'contacts': [
          {'phone': '(11) 99999-1234', 'whatsapp': true},
          {'phone': '(11) 3333-1234', 'whatsapp': false},
        ],
      };
      final poster = MissingPoster(
        cat: cat,
        report: report,
        locationName: 'Região monitorada',
      );
      expect(poster.address, 'Rua das Flores, 15, Centro');
      expect(poster.characteristics.length, 3);
      expect(poster.text, contains('Telefone / WhatsApp: (11) 99999-1234'));
      expect(poster.text, contains('Telefone: (11) 3333-1234'));
      expect(poster.text, contains('Microchip: 123456'));
      expect(
        CatSharingService.buildMissingPosterText(cat: cat, report: report),
        poster.text,
      );
    },
  );

  test('omits missing optional fields and never invents an address', () {
    final bare = Cat(
      id: 'a',
      captureNumber: 1,
      photoPath: 'cat.jpg',
      capturedAt: DateTime(2026),
    );
    final poster = MissingPoster(
      cat: bare,
      report: {},
      locationName: 'Região monitorada',
    );
    expect(poster.address, isNull);
    expect(poster.contacts, isEmpty);
    expect(poster.characteristics, isEmpty);
    expect(poster.text, isNot(contains('Microchip')));
    expect(poster.text, contains('Contato pelo chat'));
  });

  test(
    'report snapshot takes precedence over subsequently edited cat traits',
    () {
      final poster = MissingPoster(cat: cat, report: {'collar': 'Vermelha'});
      expect(poster.characteristics['Coleira'], 'Vermelha');
    },
  );
}
