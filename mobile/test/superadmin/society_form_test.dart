import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/superadmin/data/superadmin_models.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/backup_export.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/js_compat.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/society_form.dart';

void main() {
  group('JS compat', () {
    test('parseInt / Number', () {
      expect(jsParseInt('12abc'), 12);
      expect(jsParseInt('  -7'), -7);
      expect(jsParseInt('abc'), isNull);
      expect(jsParseInt(''), isNull);
      expect(jsNumber(''), 0);
      expect(jsNumber(' 40.5 '), 40.5);
      expect(jsNumber('1e2'), 100);
      expect(jsNumber('0x10'), 16);
      expect(jsNumber('40mm').isNaN, isTrue);
      expect(jsonNumber(40.0), 40);
      expect(jsonNumber(40.0) is int, isTrue);
      expect(jsonNumber(40.5), 40.5);
    });

    test('email, file name, blocks', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('a b@c.d'), isFalse);
      expect(isValidEmail('a@b'), isFalse);
      expect(safeStorageFileName('my logo (1).png'), 'my_logo__1_.png');
      expect(splitBlocksCsv(' A, B;;C ,, '), ['A', 'B', 'C']);
      expect(digitsOnly('12 34-5678', maxLength: 6), '123456');
    });
  });

  group('society form', () {
    test('emptySocietyForm defaults like the web', () {
      final f = emptySocietyForm();
      expect(f.letterheadMode, 'auto');
      expect(f.letterheadTopMm, '40');
      expect(f.letterheadBottomMm, '18');
      expect(f.terrace, TriState.unset);
      expect(f.existingPhotoUrls, isEmpty);
    });

    test('societyToForm', () {
      final s = SocietyRow.fromJson({
        'id': 'x',
        'name': 'Evergreen',
        'letterhead_mode': 'weird',
        'letterhead_top_mm': 45,
        'block_names': ['A', 'B'],
        'terrace_accessible': true,
        'has_basement': false,
        'total_floors': 6,
        'photo_urls': ['u1'],
      });
      final f = societyToForm(s.formSource);
      expect(f.letterheadMode, 'auto');
      expect(f.letterheadTopMm, '45');
      expect(f.letterheadBottomMm, '18');
      expect(f.blocksCsv, 'A, B');
      expect(f.terrace, TriState.yes);
      expect(f.basement, TriState.no);
      expect(f.basementUsable, TriState.unset);
      expect(f.totalFloors, '6');
      expect(f.existingPhotoUrls, ['u1']);
    });

    test('buildSocietyBaseRow mirrors web saveSociety', () {
      final f = SocietyFormData(
        name: '  Green Park ',
        address: ' ',
        city: 'Pune',
        totalFlats: '20 flats',
        totalFloors: 'x',
        blocksCsv: 'A; B',
        basement: TriState.no,
        basementUsable: TriState.yes,
        letterheadTopMm: '0',
        letterheadBottomMm: '22.5',
        flatSeriesFrom: ' 101 ',
        flatSeriesTo: '',
      );
      final row = buildSocietyBaseRow(f);
      expect(row['name'], 'Green Park');
      expect(row['address'], isNull);
      expect(row['city'], 'Pune');
      expect(row['total_flats'], 20);
      expect(row['total_floors'], isNull);
      expect(row['block_names'], ['A', 'B']);
      expect(row['has_basement'], isFalse);
      expect(row['basement_usable_for_residents'], isNull);
      expect(row['letterhead_top_mm'], 40);
      expect(row['letterhead_bottom_mm'], 22.5);
      expect(row['flat_series_start'], '101');
      expect(row['flat_series_end'], isNull);
      expect(row['letterhead_mode'], 'auto');
      expect(row.containsKey('photo_urls'), isFalse);
      expect(
          buildSocietyBaseRow(SocietyFormData(blocksCsv: ' , '))['block_names'],
          isNull);
      final withBasement = buildSocietyBaseRow(
          SocietyFormData(basement: TriState.yes, basementUsable: TriState.no));
      expect(withBasement['basement_usable_for_residents'], isFalse);
    });

    test('layoutFromForm', () {
      final l = layoutFromForm(SocietyFormData(
          totalFloors: '4',
          flatSeriesFrom: '101',
          flatSeriesTo: '104',
          blocksCsv: 'A'));
      expect(l.totalFloors, 4);
      expect(l.flatSeriesStart, '101');
      expect(l.blockNames, ['A']);
    });

    test('makeReferralCode (phonepe-callback)', () {
      expect(makeReferralCode('Evergreen Heights Society', '1a2b3c4d-0000'),
          'EVERHE-1A2B3C');
      expect(makeReferralCode('Evergreen Heights', 'abcdef12-3456'),
          'EVERHE-ABCDEF');
      expect(makeReferralCode('ग्रीन', 'abcdef12'), 'SOC-ABCDEF');
      expect(makeReferralCode('A1 B', 'ab-cd'), 'A1B-ABCD');
    });

    test('address line and thumbnail', () {
      final s = SocietyRow.fromJson({
        'id': '1',
        'name': 'n',
        'address': 'Road 1',
        'state': 'MH',
        'photo_urls': ['p1']
      });
      expect(s.addressLine, 'Road 1, MH');
      expect(s.thumbUrl, 'p1');
      expect(
          SocietyRow.fromJson({
            'id': '1',
            'name': 'n',
            'logo_url': 'L',
            'photo_urls': ['p1']
          }).thumbUrl,
          'L');
      expect(s.isActive, isTrue);
      expect(
          SocietyRow.fromJson({'id': '1', 'name': 'n', 'is_active': false})
              .isActive,
          isFalse);
    });
  });

  group('backup export', () {
    test('body and file names', () {
      expect(backupExportBody(),
          {'society_id': null, 'complete_db': false, 'send_email': false});
      expect(
          backupDownloadFileName(
              completeDb: false, serverFilename: 'backup_X_2026.json'),
          'backup_X_2026.json');
      final now = DateTime.utc(2026, 10, 12, 23, 30);
      expect(backupDownloadFileName(completeDb: true, now: now),
          'complete_database_CompleteDatabase_2026-10-12.json');
      expect(
          backupDownloadFileName(
              completeDb: false, societyName: 'Green Park #2', now: now),
          'backup_Green_Park__2_2026-10-12.json');
      expect(
          backupDownloadFileName(
              completeDb: false, now: now, serverFilename: 'x.txt'),
          'backup_AllSocieties_2026-10-12.json');
    });

    test('error descriptions', () {
      expect(describeBackupExportHttpError(404), contains('not found (404)'));
      expect(describeBackupExportHttpError(403), contains('401/403'));
      expect(describeBackupExportHttpError(500, serverMessage: 'boom'), 'boom');
      expect(describeBackupExportHttpError(500), 'Edge function error (500)');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      final sum = BackupSummary.fromMetadata({
        'total_records': 12,
        'total_tables': '45',
        'society_name': 'All Societies'
      });
      expect(sum.totalRecords, 12);
      expect(sum.totalTables, 45);
    });
  });

  group('onboarding + tickets', () {
    test('join orders with signups (web loadOnboarding)', () {
      final orders = [
        {
          'id': 'o1',
          'signup_id': 's1',
          'status': 'success',
          'amount_inr': 8500,
          'merchant_transaction_id': 'M1'
        },
        {
          'id': 'o2',
          'signup_id': 's1',
          'status': 'failed',
          'amount_inr': '8500'
        },
        {'id': 'o3', 'signup_id': null, 'status': 'created'},
      ];
      expect(distinctSignupIds(orders), ['s1']);
      final rows = joinOnboarding(orders, [
        {
          'id': 's1',
          'society_name': 'Evergreen',
          'status': 'provisioned',
          'contact_phone': '999'
        },
      ]);
      expect(rows.length, 3);
      expect(rows[0].societyName, 'Evergreen');
      expect(rows[1].amountInr, 8500);
      expect(rows[2].signup, isNull);
      expect(rows[0].matches('m1'), isTrue);
      expect(rows[0].matches('zzz'), isFalse);
    });

    test('parseMedia keeps objects with url', () {
      final media = parseTicketMedia([
        {'url': 'a', 'kind': 'image'},
        {'kind': 'video'},
        'x',
        {'url': 'b'},
      ]);
      expect(media.map((m) => m.url), ['a', 'b']);
      expect(media.first.kind, 'image');
      expect(parseTicketMedia('nope'), isEmpty);
    });
  });
}
