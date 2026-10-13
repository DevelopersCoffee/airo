import 'package:airo_app/features/coins/presentation/screens/group_detail_screen.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_super_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wires super-app OCR and cloud share handlers', () {
    final screen = buildSuperAppGroupDetail('group_super');

    expect(screen, isA<GroupDetailScreen>());
    expect(screen.groupId, 'group_super');
    expect(screen.openItemizedBillSplit, isNotNull);
    expect(screen.shareGroupInvite, isNotNull);
  });
}
