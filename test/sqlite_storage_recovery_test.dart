import 'dart:io';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fault in ['corrupt', 'readonly']) {
    test(
      'RES08 authoritative SQLite preserves data and recovers from $fault',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final folder = await Directory.systemTemp.createTemp('gatalogo-res08-');
        final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
        final target = await folder.resolveSymbolicLinks();
        expect(p.isWithin(temporaryRoot, target), isTrue);
        await databaseFactory.setDatabasesPath(target);
        final file = File(p.join(target, 'gatalogo.db'));
        final photo = File(p.join(target, 'private-photo.jpg'));
        Database? opened;
        try {
          await photo.writeAsBytes([1, 2, 3]);
          final original = CatDatabase();
          opened = await original.database;
          final cat = Cat(
            id: '00000000-0000-4000-8000-000000000088',
            captureNumber: 1,
            photoPath: photo.path,
            capturedAt: DateTime.utc(2026, 10, 25),
            ownerId: 'a',
            name: 'preserved',
            syncState: 'dirty',
            localUpdatedAt: DateTime.utc(2026, 10, 25),
          );
          await original.insertCat(cat);
          await original.setSyncCursor('a', 8);
          await opened.close();
          opened = null;
          final backup = await file.readAsBytes();

          if (fault == 'corrupt') {
            final corrupted = [for (var i = 0; i < 64; i++) 88];
            await file.writeAsBytes(corrupted, flush: true);
            final storage = CatDatabase();
            await expectLater(
              storage.database,
              throwsA(isA<DatabaseException>()),
            );
            expect(await file.readAsBytes(), corrupted);
            expect(await photo.readAsBytes(), [1, 2, 3]);
            // Explicit restoration of this test's closed database from its own backup.
            await file.writeAsBytes(backup, flush: true);
            opened = await storage.database;
            expect(
              (await storage.getCats(ownerId: 'a')).single.name,
              'preserved',
            );
            expect((await storage.getCatById(cat.id))!.syncState, 'dirty');
            expect(await storage.getSyncCursor('a'), '8');
          } else {
            final readOnly = await databaseFactoryFfi.openDatabase(
              file.path,
              options: OpenDatabaseOptions(
                readOnly: true,
                singleInstance: false,
              ),
            );
            opened = readOnly;
            final storage = CatDatabase.withConnection(() async => readOnly);
            await expectLater(
              storage.updateCatName(cat.id, 'must-not-persist'),
              throwsA(isA<DatabaseException>()),
            );
            expect((await storage.getCatById(cat.id))!.name, 'preserved');
            expect(await storage.getSyncCursor('a'), '8');
            await readOnly.close();
            opened = null;
            expect(await file.readAsBytes(), backup);
            final writable = CatDatabase();
            opened = await writable.database;
            await writable.updateCatName(cat.id, 'recovered');
            expect((await writable.getCatById(cat.id))!.name, 'recovered');
            expect(await writable.getSyncCursor('a'), '8');
          }
          expect(await photo.readAsBytes(), [1, 2, 3]);
        } finally {
          if (opened != null && opened.isOpen) {
            await opened.close();
          }
          expect(
            p.isWithin(temporaryRoot, await folder.resolveSymbolicLinks()),
            isTrue,
          );
          await folder.delete(recursive: true);
        }
      },
    );
  }
}
