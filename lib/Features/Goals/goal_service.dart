import '../../Core/cloud_service.dart';
import 'goal_model.dart';

class GoalService extends CloudService {
  Stream<List<GoalModel>> streamGoals() {
    return collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return GoalModel.fromFirestore(doc);
      }).toList();
    });
  }

  Future<void> saveGoal(GoalModel goal) async {
    await save('goals', goal.id, goal.toFirestore());
  }

  Future<void> deleteGoal(String id) async {
    await delete('goals', id);
  }
}
