import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'person_model.dart';

class PersonService extends CloudService {
  Stream<List<PersonModel>> streamPeople() {
    return stream('people').map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return PersonModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad person doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<PersonModel>().toList();
    });
  }

  Future<void> savePerson(PersonModel person) async {
    await save('people', person.id, person.toFirestore());
  }

  Future<void> deletePerson(String id) async {
    await delete('people', id);
  }
}
