import '../../Core/cloud_service.dart';
import 'budget_model.dart';

class BudgetService extends CloudService {
  Stream<List<BudgetModel>> streamBudgets() {
    return stream('budgets').map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return BudgetModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad budget doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<BudgetModel>().toList();
    });
  }

  Future<void> saveBudget(BudgetModel budget) async {
    await save('budgets', budget.id, budget.toFirestore());
  }

  Future<void> deleteBudget(String id) async {
    await delete('budgets', id);
  }
}
