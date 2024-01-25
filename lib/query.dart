import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_test/DB/fetch_query.dart';
import 'package:sqlite_test/DB/db_receipt.dart';
import 'package:sqlite_test/DB/db_receiptitem.dart';
import 'package:sqlite_test/DB/db_settlement.dart';
import 'package:sqlite_test/DB/db_settlementitem.dart';
import 'package:sqlite_test/DB/db_settlementpaper.dart';
import 'DB/savepoint.dart';
import 'Model/receipt.dart';
import 'Model/receipt_item.dart';
import 'Model/settlement_item.dart';
import 'Model/settlementpaper.dart';
import 'Model/settlement.dart';

class Query {

  Database? _db;

  Query(Database db) {
    _db = db;
  }

  Future<Settlement> showRecentSettlement(String stmId) async {

    Settlement settlement = await FetchQuery().fetchSettlement(_db!, stmId);
    return settlement;
  }

  Future<Map<String,List<String>>> showSettlementMembers(List<String> stmIds) async {
    Map<String,List<String>> members = {}; //key: settlementId, value: members
    stmIds.forEach((stmId) async {
      members[stmId] = await FetchQuery().fetchMembers(_db!, stmId);
    });

    return members;
  }

  Future<int> createSettlement(Settlement stm) async {
    return await DBSettlement().createStm(_db!, stm.settlementId, stm.settlementName);
  }

  Future<int> updateSettlement(Settlement stm) async {
    return await DBSettlement().updateStm(_db!, stm.settlementName, stm.settlementId);
  }

  Future<int> deleteSettlement(String stmId) async {
    return await DBSettlement().deleteStm(_db!, stmId);
  }

  Future<int> createMembers(String stmId, List<SettlementPaper> stmPapers) async {
    try {
      var res = await _db!.transaction((txn) async {
        stmPapers.forEach((stmPaper) async {
          await DBSettlementPaper().createStmPaperTxn(txn, stmPaper.settlementPaperId, stmId, stmPaper.memberName);
        });
      });
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 1;
  }

  Future<int> deleteMembers(String stmId, List<String> settlementPaperIds) async {
    try {
      var res = await _db!.transaction((txn) async {
        settlementPaperIds.forEach((stmPaperId) async {
          await DBSettlementPaper().deleteStmPaperTxn(txn, stmPaperId);
          await DBSettlementItem().deleteAllStmItemsTxn(txn, stmPaperId);
        });
      });
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 2;
  }

  Future<int> updateMemberName(String newmemberName, String stmPaperId) async {
    return DBSettlementPaper().updateStmPaper(_db!, newmemberName, stmPaperId);
  }

  Future<int> createReceipt(Receipt rcp, String stmId) async {
    return DBReceipt().createRcp(_db!, rcp.receiptId, rcp.receiptName, stmId);
  }

  Future<int> updateReceiptName(String rcpName, String rcpId) async {
    return DBReceipt().updateRcp(_db!, rcpName, rcpId);
  }

  Future<int> deleteReceipt(String rcpId) async {
    return DBReceipt().deleteRcp(_db!, rcpId);
  }

  Future<int> createRcpItem(String rcpId, ReceiptItem rcpItem) async {
    return DBReceiptItem().createReceiptItem(_db!, rcpItem.receiptItemId, rcpId, rcpItem.receiptItemName, rcpItem.price, rcpItem.count);
  }

  Future<int> updateRcpItemName(String rcpItemId, String name) async {
    return DBReceiptItem().updateReceiptItemName(_db!, name, rcpItemId);
  }

  Future<int> updateRcpItemPrice(String rcpItemId, double price) async {
    return DBReceiptItem().updateReceiptItemPrice(_db!, price, rcpItemId);
  }

  Future<int> updateRcpItemCount(String rcpItemId, int count) async {
    return DBReceiptItem().updateReceiptItemCount(_db!, count, rcpItemId);
  }

  Future<int> deleteRcpItem(String rcpItemId) async {
   return DBReceiptItem().deleteReceiptItem(_db!, rcpItemId);
  }

  //정산 매칭 시의 쿼리들(롤백 적용 필요)
  Future<int> matchingMemberToAllReceiptItems(String stmPaperId, List<String> rcpItemIds) async {

    try {
          rcpItemIds.forEach((rcpItemId) async {
            await DBSettlementItem().createStmItem(_db!, stmPaperId, rcpItemId);
          });
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 1;
  }

  Future<int> matchingMemberToReceiptItem(String stmPaperId, String rcpItemId) async {

    try {
        await DBSettlementItem().createStmItem(_db!, stmPaperId, rcpItemId);
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 1;
  }

  Future<int> unmatchingMemberFromAllReceiptItems(String stmPaperId, List<String> rcpItemIds) async {

    try {
        rcpItemIds.forEach((rcpItemId) async {
          await DBSettlementItem().deleteStmItem(_db!, stmPaperId, rcpItemId);
      });
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 1;
  }

  Future<int> unmatchingMemberFromReceiptItem(String stmPaperId, String rcpItemId) async {

    try {
        await DBSettlementItem().deleteStmItem(_db!, stmPaperId, rcpItemId);
    }
    catch (e) {
      print(e);
      return 0;
    }
    return 1;
  }

  Future<void> startTransaction(Database db) async {
    await db.execute('BEGIN TRANSACTION');
  }
  Future <void> commitTransaction(Database db) async {
    await db.execute('COMMIT');
  }

  Future<void> savepointTranscation(Database db, SavepointManager spm) async {
    String savepoint = spm!.createSavePoint();
    //String savepoint = 'my_savepoint_${++_savepointId}';
    await db.execute('SAVEPOINT $savepoint');
    log("savepoint: ${savepoint}");
  }

  Future<void> rollbackTransaction(Database db, SavepointManager spm) async {
    String savepoint = spm!.returnSavePoint();
    //String savepoint = 'my_savepoint_${_savepointId--}';
    log("savepoint: ${savepoint}");
    await db.execute('ROLLBACK TO SAVEPOINT $savepoint');
  }

}