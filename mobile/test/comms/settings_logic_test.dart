import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/flat_options.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_media_storage.dart';
import 'package:kutumbika_mobile/features/comms/data/society_settings_logic.dart';

void main() {
  group('flat order (web compareFlatNumbers, numeric collation)', () {
    test('numbers sort numerically, not lexicographically', () {
      final flats = ['1001', '102', '101', '605', '99'];
      flats.sort(compareFlatNumbers);
      expect(flats, ['99', '101', '102', '605', '1001']);
    });

    test('tower prefixes', () {
      final flats = ['B-101', 'A-1002', 'A-201', 'a-105'];
      flats.sort(compareFlatNumbers);
      expect(flats, ['a-105', 'A-201', 'A-1002', 'B-101']);
    });

    test('options use the primary member, else the owner', () {
      final options = flatOptionsWithPrimaryLabel(
        const [
          {'id': 'f2', 'flat_number': '102', 'owner_name': 'OWNER B'},
          {'id': 'f1', 'flat_number': '101', 'owner_name': '  '},
          {'id': 'f3', 'flat_number': '103', 'owner_name': null},
        ],
        const {'f2': ' PRIMARY B '},
      );
      expect(options.map((o) => o.flatNumber), ['101', '102', '103']);
      expect(options.map((o) => o.subtitle), [null, 'PRIMARY B', null]);
    });

    test('search, toggle, all visible, clear visible', () {
      const options = [
        FlatOption(id: '1', flatNumber: '101', subtitle: 'ASHA'),
        FlatOption(id: '2', flatNumber: '102', subtitle: 'RAVI'),
        FlatOption(id: '3', flatNumber: '201'),
      ];
      expect(
          filterFlatOptions(options, 'ravi').map((o) => o.flatNumber), ['102']);
      expect(filterFlatOptions(options, '10').map((o) => o.flatNumber),
          ['101', '102']);
      expect(filterFlatOptions(options, '  '), options);
      expect(toggleFlat(['101'], '102'), ['101', '102']);
      expect(toggleFlat(['101', '102'], '101'), ['102']);
      final visible = filterFlatOptions(options, '10');
      expect(selectAllVisible(['201'], visible), ['201', '101', '102']);
      expect(clearVisible(['201', '101', '102'], visible), ['201']);
    });
  });

  group('storage file names (web sanitizeStorageFileName)', () {
    test('non word characters become underscores', () {
      expect(sanitizeStorageFileName('My Photo (1).jpg'), 'My_Photo__1_.jpg');
      expect(sanitizeStorageFileName('बिल.pdf'), '___.pdf');
      expect(sanitizeStorageFileName('a-b_c.mp3'), 'a-b_c.mp3');
    });
  });

  group('letterhead + address', () {
    test('address line joins non-empty parts with ·', () {
      expect(
        letterheadAddressLine(
            address: ' Plot 4, MG Road ',
            city: 'PUNE',
            state: 'MAHARASHTRA',
            pincode: '411001'),
        'Plot 4, MG Road · PUNE, MAHARASHTRA · 411001',
      );
      expect(letterheadAddressLine(city: 'PUNE'), 'PUNE');
      expect(letterheadAddressLine(state: 'MH', pincode: ''), 'MH');
      expect(letterheadAddressLine(), '');
    });

    test('address patch trims and nulls blanks', () {
      expect(
          buildAddressPatch(
              address: ' A ', city: '', state: '  ', pincode: '411001'),
          {
            'address': 'A',
            'city': null,
            'state': null,
            'pincode': '411001',
          });
    });

    test('layout inputs fall back when not positive numbers', () {
      expect(parseLayoutMm('45', 40), 45);
      expect(parseLayoutMm(' 12.5 ', 40), 12.5);
      expect(parseLayoutMm('', 22), 22);
      expect(parseLayoutMm('0', 22), 22);
      expect(parseLayoutMm('-3', 22), 22);
      expect(parseLayoutMm('abc', 19.05), 19.05);
    });

    test('row normalisation defaults (web normalizeSocietyRow)', () {
      final lh = SocietyLetterheadInfo.fromRow(
          const {'name': 'GREEN HEIGHTS', 'default_report_format': 'plain'});
      expect(lh.topMm, 40);
      expect(lh.bottomMm, 18);
      expect(lh.leftMm, 19.05);
      expect(lh.rightMm, 19.05);
      expect(lh.defaultReportFormat, 'plain');
      expect(lh.letterheadMode, 'auto');
      expect(lh.hasLetterhead, isFalse);
      expect(
          SocietyLetterheadInfo.fromRow(
                  const {'letterhead_storage_path': 's/letterhead/x.png'})
              .hasLetterhead,
          isTrue);
    });

    test('report settings patch', () {
      final current = SocietyLetterheadInfo.fromRow(const {
        'name': 'X',
        'letterhead_storage_path': 'p.png',
        'letterhead_mode': 'auto'
      });
      final patch = buildReportSettingsPatch(
        defaultFormat: 'letterhead',
        top: '50',
        bottom: 'x',
        left: '0',
        right: '20',
        current: current,
      );
      expect(patch, {
        'default_report_format': 'letterhead',
        'letterhead_top_mm': 50.0,
        'letterhead_bottom_mm': 22.0,
        'letterhead_left_mm': 19.05,
        'letterhead_right_mm': 20.0,
        'letterhead_mode': 'image',
      });
      expect(letterheadModeForSave(currentMode: 'stationery'), 'stationery');
      expect(letterheadModeForSave(), 'auto');
      expect(formatMm(45), '45');
      expect(formatMm(19.05), '19.05');
    });
  });

  group('bank account (web societyBankAccountService)', () {
    test('required fields', () {
      expect(bankAccountInputComplete(const BankAccountInput()), isFalse);
      expect(
        bankAccountInputComplete(const BankAccountInput(
            bankName: 'HDFC',
            accountHolderName: 'SOC',
            accountNumber: '1',
            ifsc: 'X')),
        isTrue,
      );
    });

    test('payload normalisation', () {
      final p = buildBankAccountPayload(
        's1',
        const BankAccountInput(
          bankName: ' HDFC Bank ',
          accountHolderName: ' M/S GREEN ',
          accountNumber: ' 5010 0012 3456 ',
          ifsc: ' hdfc0001234 ',
          branchName: '',
          upiVpa: ' soc@okhdfc ',
          currency: '',
        ),
      );
      expect(p['bank_name'], 'HDFC Bank');
      expect(p['account_holder_name'], 'M/S GREEN');
      expect(p['account_number'], '501000123456');
      expect(p['ifsc'], 'HDFC0001234');
      expect(p['branch_name'], isNull);
      expect(p['upi_vpa'], 'soc@okhdfc');
      expect(p['currency'], 'INR');
      expect(p['is_primary'], isTrue);
      expect(p['is_active'], isTrue);
      expect(p['effective_from'], isNull);
      expect(p['effective_to'], isNull);
    });

    test('copyable details and masking', () {
      const a = SocietyBankAccountRow(
        id: '1',
        societyId: 's1',
        bankName: 'HDFC',
        accountHolderName: 'SOC',
        accountNumber: '123456789',
        ifsc: 'HDFC0001',
        branchName: 'MG ROAD',
      );
      expect(copyableBankDetails(a),
          'Account name: SOC\nBank: HDFC\nAccount number: 123456789\nIFSC: HDFC0001\nBranch: MG ROAD');
      expect(maskAccountNumber('1234 5678 9'), '•••••6789');
      expect(maskAccountNumber('123'), '123');
    });

    test('form from account keeps the date part of effective_from', () {
      final input =
          BankAccountInput.fromAccount(SocietyBankAccountRow.fromRow(const {
        'id': '1',
        'society_id': 's1',
        'bank_name': 'B',
        'account_holder_name': 'H',
        'account_number': 'N',
        'ifsc': 'I',
        'currency': null,
        'effective_from': '2026-04-01T00:00:00',
        'is_primary': true,
        'is_active': true,
      }));
      expect(input.effectiveFrom, '2026-04-01');
      expect(input.currency, 'INR');
    });
  });

  group('banners', () {
    test('next sort order and swap neighbours', () {
      expect(nextBannerSortOrder(const []), 1);
      expect(
        nextBannerSortOrder(const [
          {'sort_order': 3},
          {'sort_order': '7'},
          {'sort_order': null},
        ]),
        8,
      );
      expect(bannerSwapIndex(0, -1, 3), isNull);
      expect(bannerSwapIndex(0, 1, 3), 1);
      expect(bannerSwapIndex(2, 1, 3), isNull);
      expect(bannerSwapIndex(-1, 1, 3), isNull);
    });
  });
}
