import 'dart:async';
import 'package:flutter/material.dart';
import '../Auth/user_model.dart';
import 'person_model.dart';
import 'person_service.dart';
import 'connection_request_model.dart';
import 'user_connection_model.dart';

class PersonProvider extends ChangeNotifier {
  final PersonService _service = PersonService();
  List<PersonModel> _people = [];
  List<UserConnectionModel> _connections = [];
  List<ConnectionRequestModel> _incomingRequests = [];
  List<ConnectionRequestModel> _sentRequests = [];
  
  StreamSubscription? _subscription;
  StreamSubscription? _connSub;
  StreamSubscription? _incomingSub;
  StreamSubscription? _sentSub;

  List<PersonModel> get people => _people;
  List<UserConnectionModel> get connections => _connections;
  List<ConnectionRequestModel> get incomingRequests => _incomingRequests;
  List<ConnectionRequestModel> get sentRequests => _sentRequests;

  String? _currentUserId;

  void updateUserId(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _cancelSubs();
    if (userId != null) {
      _init(userId);
    }
  }

  void _init(String userId) {
    _subscription = _service.streamPeople().listen((people) {
      _people = people;
      notifyListeners();
    }, onError: (e) {
      debugPrint("PersonProvider Error: $e");
    });

    _connSub = _service.streamConnections(userId).listen((conns) {
      _connections = conns;
      notifyListeners();
    }, onError: (e) {
      debugPrint("PersonProvider (Connections) Error: $e");
    });

    _incomingSub = _service.streamIncomingRequests(userId).listen((reqs) {
      _incomingRequests = reqs;
      notifyListeners();
    }, onError: (e) {
      debugPrint("PersonProvider (Incoming) Error: $e");
    });

    _sentSub = _service.streamSentRequests(userId).listen((reqs) {
      _sentRequests = reqs;
      notifyListeners();
    }, onError: (e) {
      debugPrint("PersonProvider (Sent) Error: $e");
    });
  }

  void _cancelSubs() {
    _subscription?.cancel();
    _connSub?.cancel();
    _incomingSub?.cancel();
    _sentSub?.cancel();
  }

  Future<UserModel?> searchUser(String email) async {
    return await _service.searchUserByEmail(email);
  }

  Future<void> sendRequest(UserModel targetUser, UserModel currentUser) async {
    final request = ConnectionRequestModel(
      senderId: currentUser.ledgixId,
      receiverId: targetUser.ledgixId,
      senderEmail: currentUser.email,
      receiverEmail: targetUser.email,
      senderName: currentUser.name,
      createdAt: DateTime.now(),
    );
    await _service.sendConnectionRequest(request);
  }

  Future<void> acceptRequest(ConnectionRequestModel request, String currentUserName) async {
    await _service.acceptConnectionRequest(request, currentUserName);
  }

  Future<void> rejectRequest(String requestId) async {
    await _service.rejectConnectionRequest(requestId);
  }

  Future<void> removeConnection(UserConnectionModel connection) async {
    if (_currentUserId == null) return;
    await _service.removeConnection(connection.id!, _currentUserId!, connection.connectedUserId);
  }

  Future<void> savePerson(PersonModel person) async {
    await _service.savePerson(person);
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}
