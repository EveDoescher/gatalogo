import 'package:catlogue/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/missing_poster.dart';
import 'package:catlogue/services/cat_sharing_service.dart';
import 'package:catlogue/services/missing_poster_export.dart';

import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
    'hidden fields and unselected contacts never reach public exports',
    () async {
      final poster = MissingPoster(
        cat: cat,
        report: {
          'created_at': '2026-10-04T12:00:00Z',
          'last_seen_address': 'Endereço privado',
          'poster_options': {
            'address': false,
            'microchip': false,
            'date': false,
            'qr_code': false,
          },
          'poster_contacts': [
            {'phone': '11999991234', 'whatsapp': true, 'included': true},
            {'phone': '1133331234', 'whatsapp': false, 'included': false},
          ],
        },
      );
      expect(poster.text, isNot(contains('Endereço privado')));
      expect(poster.text, isNot(contains('Microchip')));
      expect(poster.text, isNot(contains('04/10/2026')));
      expect(poster.text, isNot(contains('1133331234')));
      expect(poster.contacts.length, 1);
      expect(poster.includes('qr_code'), false);
      final bytes = await MissingPosterExport.pdf(poster);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );
  test('public reports cannot fall back to private cat traits', () {
    final public = MissingPoster.publicReport(
      report: {
        'name': 'Lua',
        'poster_options': {'microchip': false},
        'collar': 'Azul',
      },
      photoBytes: null,
    );
    expect(public.displayName, 'Lua');
    expect(public.characteristics, {'Coleira': 'Azul'});
    expect(public.text, isNot(contains('123456')));
  });

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
  test('QR preserves the report link and never invents an empty report ID', () {
    expect(
      MissingPoster(cat: cat, report: {'id': 'real-report'}).qrPayload,
      '${ApiConfig.baseUrl}/public/busca/real-report',
    );
    final draft = MissingPoster(cat: cat, report: {});
    expect(draft.qrPayload, draft.text);
    expect(draft.qrPayload, isNot(contains('/busca/')));
  });
  test(
    'print export is a complete standalone PDF with a single page',
    () async {
      final poster = MissingPoster(
        cat: cat.withSync(
          photoPath: File(
            'assets/gatalogo_asset_library/cats/cat_orange_sleeping.png',
          ).absolute.path,
        ),
        report: {
          'id': 'report-lua',
          'last_seen_address': 'Rua das Flores, 15, Centro',
          'created_at': '2026-10-04T12:00:00Z',
          'contacts': [
            {'phone': '(11) 99999-1234', 'whatsapp': true},
          ],
        },
      );
      expect(poster.text, contains('04/10/2026'));
      final bytes = await MissingPosterExport.pdf(poster);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      await Directory('build/galeria-visual').create(recursive: true);
      await File('build/galeria-visual/cartaz-impressao.pdf')
          .writeAsBytes(bytes);
    },
  );
}
