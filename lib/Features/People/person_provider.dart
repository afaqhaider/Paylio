import 'dart:async';
import 'package:flutter/material.dart';
import 'person_model.dart';
import 'person_service.dart';

class PersonProvider extends ChangeNotifier {
  final PersonService _service = PersonService();
  List<PersonModel> _people = [];
  StreamSubscription? _subscription;

  List<PersonModel> get people => _people;

  PersonProvider() {
    _init();
  }

  void _init() {
    _subscription = _service.streamPeople().listen((people) {
      _people = people;
      notifyListeners();
    }, onError: (e) {
      debugPrint("PersonProvider Error: $e");
    });
  }

  Future<void> savePerson(PersonModel person) async {
    await _service.savePerson(person);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
