import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite_test/View/menu_sheet.dart';
import 'package:sqlite_test/View/receipt_circulator.dart';

import '../Model/ReceiptItem.dart';
import '../ViewModel/mainviewmodel.dart';
import '../theme.dart';
import 'bottom_sheet.dart';

final settlementMatchingProvider = ChangeNotifierProvider((ref) => SettlementMatchingViewmodel());

class SettlementMatchingViewmodel extends ChangeNotifier{
  ScrollController receiptScrollController = ScrollController();
  int presentReceiptIndex = 0;
  List<bool> selectedReceiptItemIndexList = [];
  List<bool> selectedMemberIndexList = [];

  void settingMemberIndexList(int length){
    selectedMemberIndexList = List.generate(length, (index) => false);
    notifyListeners();
  }

  void selectReceipt(int index,int receiptItemLength){
    presentReceiptIndex = index;
    selectedMemberIndexList = List.generate(selectedMemberIndexList.length, (index) => false);
    selectedReceiptItemIndexList = List.generate(receiptItemLength, (index) => false);
    notifyListeners();
  }

  void selectReceiptItem(int index){
    selectedReceiptItemIndexList[index] = !selectedReceiptItemIndexList[index];
    notifyListeners();
  }

  void selectMember(int index){
    selectedMemberIndexList[index] = !selectedMemberIndexList[index];
    notifyListeners();
  }
}

class SettlementMatching extends ConsumerStatefulWidget {
  const SettlementMatching({super.key});

  @override
  ConsumerState<SettlementMatching> createState() => _SettlementMatchingState();
}

class _SettlementMatchingState extends ConsumerState<SettlementMatching> {
  @override
  Widget build(BuildContext context) {
    final size =  MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: basic[8],
          ),
        ),
        const ReceiptCirculator(),
        const CustomBottomSheet(childWidget: MenuSheet(),),
        Positioned(
          bottom: 0,
          child: GroupMembers()
        ),
      ],
    );
  }
}

class GroupMembers extends ConsumerWidget {
  const GroupMembers({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: 100,
      color: basic[2]
    );
  }
}






