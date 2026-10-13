import 'group_detail_cloud_share.dart';
import 'group_detail_itemized_bill.dart';
import 'group_detail_screen.dart';

/// Super-app group detail with receipt OCR and cloud invite share wired in.
GroupDetailScreen buildSuperAppGroupDetail(String groupId) {
  return GroupDetailScreen(
    groupId: groupId,
    openItemizedBillSplit: openGroupItemizedBillSplit,
    shareGroupInvite: shareGroupInviteWithCloud,
  );
}
