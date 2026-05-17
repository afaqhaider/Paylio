import '../../Core/cloud_service.dart';
import 'category_model.dart';

class CategoryService extends CloudService {
  Stream<List<CategoryModel>> streamCategories(String type) {
    return collection('categories')
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return CategoryModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad category doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<CategoryModel>().toList();
    });
  }

  Future<void> saveCategory(CategoryModel category) async {
    await save('categories', category.id, category.toFirestore());
  }

  Future<void> deleteCategory(String id) async {
    await delete('categories', id);
  }
}
