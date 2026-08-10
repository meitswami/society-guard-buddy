class SocietyBankAccount {
  const SocietyBankAccount({
    required this.id,
    required this.societyId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifsc,
    this.branchName,
    this.upiVpa,
  });

  final String id;
  final String societyId;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifsc;
  final String? branchName;
  final String? upiVpa;

  factory SocietyBankAccount.fromRow(Map<String, dynamic> row) => SocietyBankAccount(
        id: row['id'] as String,
        societyId: row['society_id'] as String,
        bankName: row['bank_name'] as String,
        accountHolderName: row['account_holder_name'] as String,
        accountNumber: row['account_number'] as String,
        ifsc: row['ifsc'] as String,
        branchName: row['branch_name'] as String?,
        upiVpa: row['upi_vpa'] as String?,
      );

  String get copyableDetails {
    final lines = <String>[
      'Account name: $accountHolderName',
      'Bank: $bankName',
      'Account number: $accountNumber',
      'IFSC: $ifsc',
    ];
    if (branchName != null && branchName!.trim().isNotEmpty) {
      lines.add('Branch: $branchName');
    }
    if (upiVpa != null && upiVpa!.trim().isNotEmpty) {
      lines.add('UPI: $upiVpa');
    }
    return lines.join('\n');
  }
}
