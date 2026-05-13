import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'category_model.dart';

class CategoryService extends CloudService {
  Stream<List<CategoryModel>> streamCategories(String type) {
    return collection('categories')
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveCategory(CategoryModel category) async {
    await save('categories', category.id, category.toFirestore());
  }

  Future<void> deleteCategory(String id) async {
    await delete('categories', id);
  }
}
