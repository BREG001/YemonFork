import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_test/DB/sqlflite_db.dart';
import 'package:sqlite_test/shared_tool.dart';
import '../Model/receipt.dart';
import '../Model/receipt_item.dart';
import '../Model/settlement.dart';
import '../Model/settlement_item.dart';
import '../Model/settlementpaper.dart';

final mainProvider = ChangeNotifierProvider((ref) => MainViewModel());

class MainViewModel extends ChangeNotifier {
  var db = SqlFliteDB().database;
  List<Settlement> settlementList = [];
  Settlement selectedSettlement = Settlement();

  List<List<List<TextEditingController>>> receiptItemControllerList = [];
  List<List<bool>> selectedReceiptItemIndexList = [];
  List<bool> selectedMemberIndexList = [];

  List<dynamic> getReceiptInformationBySettlementPaper(int paperHashcode) {
    for (var receipt in selectedSettlement.receipts) {
      for (var receiptItem in receipt.receiptItems) {
        for (var code in receiptItem.paperOwner.values) {
          if (code == paperHashcode) {
            return [receipt.receiptName, receiptItem.price];
          }
        }
      }
    }
    return ["null", "null"];
  }

  void changeAllMember(bool changeBool){
    selectedMemberIndexList = List.generate(selectedMemberIndexList.length, (index) => changeBool);
    notifyListeners();
  }

  void selectReceiptItem(int receiptIndex, int receiptItemIndex){
    selectedReceiptItemIndexList[receiptIndex][receiptItemIndex] = true;
    notifyListeners();
  }

  void selectMember(int index){
    selectedMemberIndexList[index] = !selectedMemberIndexList[index];
    notifyListeners();
  }

  void selectSettlement(int index){
    selectedSettlement = settlementList[index];
    notifyListeners();
  }

  void unmatching(int receiptIndex, int receiptItemIndex, String paperId) {
    String menuName = selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].receiptItemName;

    //change splitPrice
    double splitPrice = selectedSettlement
            .receipts[receiptIndex].receiptItems[receiptItemIndex].price /
        (selectedSettlement.receipts[receiptIndex]
                .receiptItems[receiptItemIndex].paperOwner.length -
            1);

    selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].paperOwner
        .forEach((key, value) {
      selectedSettlement.settlementPapers
          .firstWhere((element) => element.settlementPaperId == key)
          .settlementItems
          .firstWhere((element) => element.name == menuName)
          .splitPrice = splitPrice == double.infinity ? 0 : splitPrice;
    });

    //remove settlementItem from settlementPaper
    selectedSettlement.settlementPapers
        .firstWhere((element) => element.settlementPaperId == paperId)
        .settlementItems
        .removeWhere((element) =>
            element.hashCode ==
            selectedSettlement.receipts[receiptIndex]
                .receiptItems[receiptItemIndex].paperOwner[paperId]);

    //remove paperOwner from receiptItem
    selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].paperOwner
        .removeWhere((key, value) => key == paperId);

    updateMemberTotalPrice();
    notifyListeners();
  }

  void batchMatching(int presentReceiptIndex) {
    for (int i = 0;
        i < selectedReceiptItemIndexList[presentReceiptIndex].length;
        i++) {
      if (selectedReceiptItemIndexList[presentReceiptIndex][i]) {
        for (int j = 0; j < selectedMemberIndexList.length; j++) {
          if (selectedMemberIndexList[j]) {
            matching(j, i, presentReceiptIndex);
          }
        }
        selectedReceiptItemIndexList[presentReceiptIndex][i] = false;
        updateSettlementItemSplitPrice(presentReceiptIndex, i);
      }
    }
    
  }

  void matching(int userIndex, int itemIndex, int receiptIndex) {
    //if already matched
    if (selectedSettlement
        .receipts[receiptIndex].receiptItems[itemIndex].paperOwner
        .containsKey(
            selectedSettlement.settlementPapers[userIndex].settlementPaperId)) {
      return;
    }

    //add settlementItem to settlementPaper
    SettlementItem newSettlementItem = SettlementItem(selectedSettlement
        .receipts[receiptIndex].receiptItems[itemIndex].receiptItemName);
    selectedSettlement.settlementPapers[userIndex].settlementItems
        .add(newSettlementItem);

    //add paperOwner to receiptItem
    selectedSettlement
                .receipts[receiptIndex].receiptItems[itemIndex].paperOwner[
            selectedSettlement.settlementPapers[userIndex].settlementPaperId] =
        selectedSettlement
            .settlementPapers[userIndex].settlementItems.last.hashCode;
    updateMemberTotalPrice();
    notifyListeners();
  }

//영수증 이름 수정
  void editReceiptName(String newName, int receiptIndex) {
    selectedSettlement.receipts[receiptIndex].receiptName = newName;
    notifyListeners();
  }

//정산 이름 수정
  void editSettlementName(String newName) {
    selectedSettlement.settlementName = newName;
    notifyListeners();
  }

//멤버 이름 수정
  void editMemberName(String newName, int index) {
    selectedSettlement.settlementPapers[index].memberName = newName;
    notifyListeners();
  }

//ReceiptItem 이름 수정
  void editReceiptItemName(
      String newName, int receiptIndex, int receiptItemIndex) {
    selectedSettlement.receipts[receiptIndex].receiptItems[receiptItemIndex]
        .receiptItemName = newName;
    editAllSettlementItemName(receiptIndex, receiptItemIndex, newName);
    notifyListeners();
  }

//ReceiptItem을 포함하는 모든 SettlementItem의 이름 수정
  void editAllSettlementItemName(
      int receiptIndex, int receiptItemIndex, String newName) {
    List<int> hashcodes = selectedSettlement.receipts[receiptIndex]
        .receiptItems[receiptItemIndex].paperOwner.values as List<int>;

    for (var papers in selectedSettlement.settlementPapers) {
      for (var stmItem in papers.settlementItems) {
        if (hashcodes.contains(stmItem.hashCode)) {
          stmItem.name = newName;
        }
      }
    }
    notifyListeners();
  }

//ReceiptItem 값 수정
  void editReceiptItemIndividualPrice(
      double newIndividualPrice, int receiptIndex, int receiptItemIndex) {
    int count = selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].count;

    selectedSettlement.receipts[receiptIndex].receiptItems[receiptItemIndex]
        .individualPrice = newIndividualPrice;
    selectedSettlement.receipts[receiptIndex].receiptItems[receiptItemIndex]
        .price = newIndividualPrice * count;

    receiptItemControllerList[receiptIndex][receiptItemIndex][1].text =
        priceToString.format(newIndividualPrice.truncate());
    receiptItemControllerList[receiptIndex][receiptItemIndex][3].text =
        priceToString.format(newIndividualPrice * count.truncate());

    updateReceiptTotalPrice(receiptIndex);
    notifyListeners();
  }

  void editReceiptItemCount(
      int newCount, int receiptIndex, int receiptItemIndex) {
    double individualPrice = selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].individualPrice;

    selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].count = newCount;
    selectedSettlement.receipts[receiptIndex].receiptItems[receiptItemIndex]
        .price = newCount * individualPrice;

    receiptItemControllerList[receiptIndex][receiptItemIndex][2].text =
        newCount.toString();
    receiptItemControllerList[receiptIndex][receiptItemIndex][3].text =
        priceToString.format(newCount * individualPrice.truncate());

    updateReceiptTotalPrice(receiptIndex);
    notifyListeners();
  }

  void editReceiptItemPrice(
      double newPrice, int receiptIndex, int receiptItemIndex) {
    selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].price = newPrice;
    int count = selectedSettlement
        .receipts[receiptIndex].receiptItems[receiptItemIndex].count;
    double individulPrice = newPrice / count;
    selectedSettlement.receipts[receiptIndex].receiptItems[receiptItemIndex]
        .individualPrice = individulPrice;

    receiptItemControllerList[receiptIndex][receiptItemIndex][1].text =
        priceToString.format(individulPrice.truncate());
    receiptItemControllerList[receiptIndex][receiptItemIndex][3].text =
        priceToString.format(newPrice.truncate());

    updateReceiptTotalPrice(receiptIndex);
    notifyListeners();
  }

//수정된 ReceiptItem에 해당하는 SettlementItem의 splitPrice 수정
  void updateSettlementItemSplitPrice(int receiptIndex, int itemIndex) {
    double splitPrice = selectedSettlement
            .receipts[receiptIndex].receiptItems[itemIndex].price /
        selectedSettlement.receipts[receiptIndex].receiptItems[itemIndex].count;

    selectedSettlement.receipts[receiptIndex].receiptItems[itemIndex].paperOwner
        .forEach((key, value) {
      selectedSettlement.settlementPapers
          .firstWhere((element) {
            return element.settlementPaperId == key;
          })
          .settlementItems
          .firstWhere((element) {
            return element.hashCode == value;
          })
          .splitPrice = splitPrice;
    });
  }

//값이 변경된 ReceiptItem의 Receipt와 Settlement의 totalPrice를 수정
  void updateReceiptTotalPrice(receiptIndex) {
    double total = 0;
    for (ReceiptItem receiptItem
        in selectedSettlement.receipts[receiptIndex].receiptItems) {
      total += receiptItem.price;
    }
    selectedSettlement.receipts[receiptIndex].totalPrice = total;
    total = 0;
    for (Receipt receipt in selectedSettlement.receipts) {
      total += receipt.totalPrice;
    }
    selectedSettlement.totalPrice = total;
    notifyListeners();
  }

//모든 사용자의 totalPrice를 수정
  void updateMemberTotalPrice() {
    for (var element in selectedSettlement.settlementPapers) {
      element.totalPrice = 0;
      for (var item in element.settlementItems) {
        element.totalPrice += item.splitPrice;
      }
    }
    notifyListeners();
  }

//정산 삭제
  void deleteSettlement(int index) {
    settlementList.removeAt(index);
    notifyListeners();
  }

//정산멤버 삭제
  void deleteMember(int index) {
    String id = selectedSettlement.settlementPapers[index].settlementPaperId;
    deleteMemberDataFromSettlement(id);
    selectedSettlement.settlementPapers.removeAt(index);
    selectedMemberIndexList.removeAt(index);
    notifyListeners();
  }

//Receipt List로 삭제
  void deleteReceiptList(List<bool> isSelectedReceiptList) {
    for (int i = isSelectedReceiptList.length - 1; i >= 0; i--) {
      if (isSelectedReceiptList[i]) {
        selectedSettlement.receipts.removeAt(i);
        receiptItemControllerList.removeAt(i);
        selectedReceiptItemIndexList.removeAt(i);
      }
    }
    notifyListeners();
  }

//ReceiptList에 대해 ReceiptItemList로 삭제
  void deleteReceiptItemList(List<List<bool>> receiptItems) {
    for (int i = receiptItems.length - 1; i >= 0; i--) {
      for (int j = receiptItems[i].length - 1; j >= 0; j--) {
        if (receiptItems[i][j]) {
          selectedSettlement.receipts[i].receiptItems.removeAt(j);
          receiptItemControllerList[i].removeAt(j);
          selectedReceiptItemIndexList[i].removeAt(j);
        }
      }
    }
    notifyListeners();
  }

//Member매칭정보 삭제
  void deleteMemberDataFromSettlement(String id) {
    for (Receipt receipt in selectedSettlement.receipts) {
      for (ReceiptItem receiptItem in receipt.receiptItems) {
        if (receiptItem.paperOwner.containsKey(id)) {
          receiptItem.paperOwner.remove(id);
        }
      }
    }
  }

//정산추가
  void addNewSettlement() {
    settlementList.insert(0, Settlement());
    selectedSettlement = settlementList[0];
    addMember("나");
    
    notifyListeners();
  }

//정산멤버 추가
  void addMember(String memberName) {
    SettlementPaper newSettlementPaper = SettlementPaper();
    newSettlementPaper.memberName = memberName;
    selectedSettlement.settlementPapers.add(newSettlementPaper);
    addSelectedMemberIndexList();
    notifyListeners();
  }

//정산멤버 관리 리스트 (Matching시 isSelected로 사용)
  void addSelectedMemberIndexList() {
    selectedMemberIndexList.add(false);
  }

//Receipt 추가
  void addReceipt() {
    Receipt newReceipt = Receipt();
    newReceipt.receiptId = DateTime.now().toString();
    selectedSettlement.receipts.add(newReceipt);

    addReceiptItemControllerList();
    addSelectedReceiptItemIndexList();
    notifyListeners();
  }

//ReceiptItem 입력 Controller list, 빈List를 추가 (정산정보입력시 사용)
  void addReceiptItemControllerList() {
    receiptItemControllerList.add([]);
  }

//ReceiptItem 선택 리스트, 빈list 추가 (Matching시 isSelected로 사용)
  void addSelectedReceiptItemIndexList() {
    selectedReceiptItemIndexList.add([]);
  }

//ReceiptItem 추가
  void addReceiptItem(int index) {
    ReceiptItem newReceiptItem = ReceiptItem();
    selectedSettlement.receipts[index].receiptItems.add(newReceiptItem);

    addReceiptItemTextEditingController(index, newReceiptItem);
    addSelectedReceiptItemIndexListItem(index);
    notifyListeners();
  }

//ReceiptItem 입력 Controller, TextEditing Controller 4개 추가
  void addReceiptItemTextEditingController(
      int index, ReceiptItem newReceiptItem) {
    receiptItemControllerList[index]
        .add(List.generate(4, (index) => TextEditingController()));

    initializeReceiptItemController(index, newReceiptItem);
  }

//ReceiptItem 선택 리스트, index번째에 false인 ReceiptItem isSelected 추가
  void addSelectedReceiptItemIndexListItem(int index) {
    selectedReceiptItemIndexList[index].add(false);
  }

//ReceiptItem TextEditingController 초기화
  void initializeReceiptItemController(int index, ReceiptItem newReceiptItem) {
    receiptItemControllerList[index]
            [receiptItemControllerList[index].length - 1][0]
        .text = newReceiptItem.receiptItemName;
    receiptItemControllerList[index]
            [receiptItemControllerList[index].length - 1][1]
        .text = newReceiptItem.individualPrice.toInt().toString();
    receiptItemControllerList[index]
            [receiptItemControllerList[index].length - 1][2]
        .text = newReceiptItem.count.toString();
    receiptItemControllerList[index]
            [receiptItemControllerList[index].length - 1][3]
        .text = newReceiptItem.price.toInt().toString();
  }

  void loadMemberList(int index) {
    for (SettlementPaper settlementPaper
        in settlementList[index].settlementPapers) {
      SettlementPaper newSettlementPaper = SettlementPaper();
      newSettlementPaper.memberName = settlementPaper.memberName;
      selectedSettlement.settlementPapers.add(newSettlementPaper);
    }
    notifyListeners();
  }
}
