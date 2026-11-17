import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'attempt_repository.dart';
import 'dev_flags.dart';
import 'models/question.dart';
import 'quiz_state.dart';
import 'services/trivia_service.dart';

class QuizController extends ChangeNotifier {
  QuizController({required this.uid});
  final String uid;

  QuizState state = QuizState.loading;
  List<Question> questions = const [];
  final List<String?> selections = List<String?>.filled(10, null);
  int index = 0;
  int correctCount = 0;
  String? roundId;
  String? message;

  DateTime? _lastFetchAt;
  AttemptRepository? _repo;

  bool get _locked =>
      state == QuizState.submitting ||
      state == QuizState.verifying ||
      state == QuizState.saveUnknown ||
      state == QuizState.verificationUnavailable;

  void _set(QuizState next, {String? msg}) {
    state = next;
    message = msg;
    notifyListeners();
  }

  String _newRoundId() => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('attempts')
      .doc()
      .id;

  Future<void> startRound() async {
    roundId = _newRoundId(); // ONE id per round
    _repo = AttemptRepository(uid: uid, roundId: roundId!);
    for (var i = 0; i < 10; i++) {
      selections[i] = null;
    }
    index = 0;
    correctCount = 0;
    await fetch();
  }

  Future<void> fetch() async {
    if (_lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < const Duration(seconds: 5)) {
      _set(
        QuizState.requestError,
        msg: 'OpenTDB rate limit — wait 5 s before retrying.',
      );
      return;
    }
    _lastFetchAt = DateTime.now();
    _set(QuizState.loading);
    try {
      questions = await TriviaService.fetch();
      _set(QuizState.playing);
    } on QuizException catch (e) {
      _set(QuizState.requestError, msg: e.message);
    } catch (e) {
      _set(QuizState.requestError, msg: 'Unexpected error: $e');
    }
  }

  void answer(String choice) {
    if (state != QuizState.playing) return;
    if (selections[index] != null) return; // double-tap guard
    selections[index] = choice;
    if (choice == questions[index].correct) correctCount++;
    notifyListeners();
  }

  void next() {
    if (state != QuizState.playing) return;
    if (selections[index] == null) return; // must answer first
    if (index == 9) {
      _set(QuizState.readyToSubmit);
    } else {
      index++;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    if (state != QuizState.readyToSubmit) return; // double-Submit guard
    _set(QuizState.submitting);
    try {
      await _repo!.submit(correctCount: correctCount);
      _set(QuizState.cloudVerified);
    } on LostAckInjected {
      _set(
        QuizState.saveUnknown,
        msg:
            'Acknowledgement lost. The write may have committed. '
            'Reconcile with the same round ID.',
      );
    } on AttemptCollision {
      _set(
        QuizState.permissionDenied,
        msg:
            'An attempt already exists with different data. '
            'The original was preserved.',
      );
    } on VerificationUnavailable {
      _set(
        QuizState.verificationUnavailable,
        msg:
            'Commit not proven. Verification unavailable — this is NOT '
            'a failed save.',
      );
    } on FirebaseException catch (e) {
      _set(_mapCloud(e), msg: _cloudText(e));
    } catch (e) {
      _set(QuizState.requestError, msg: 'Save error: $e');
    }
  }

  Future<void> reconcile() async {
    if (state != QuizState.saveUnknown &&
        state != QuizState.verificationUnavailable &&
        state != QuizState.requestError) {
      return;
    }
    _set(QuizState.verifying);
    try {
      await _repo!.verify(correctCount: correctCount);
      _set(QuizState.cloudVerified);
    } on FirebaseException catch (e) {
      _set(_mapCloud(e), msg: _cloudText(e));
    } on VerificationUnavailable {
      _set(
        QuizState.verificationUnavailable,
        msg:
            'Still no matching server document. Retry the submission '
            'with the same round ID.',
      );
    }
  }

  Future<void> replay() async {
    if (_locked) return;
    await startRound();
  }

  QuizState _mapCloud(FirebaseException e) {
    if (kInjectCloudFault == InjectCloudFault.unavailable ||
        kInjectCloudFault == InjectCloudFault.resourceExhausted) {
      return QuizState.requestError;
    }
    switch (e.code) {
      case 'permission-denied':
        return QuizState.permissionDenied;
      case 'unauthenticated':
        return QuizState.authError;
      default:
        return QuizState.requestError;
    }
  }

  String _cloudText(FirebaseException e) {
    if (kInjectCloudFault == InjectCloudFault.unavailable) {
      return 'DEV: cloud unavailable. Nothing is proven saved.';
    }
    if (kInjectCloudFault == InjectCloudFault.resourceExhausted) {
      return 'DEV: quota exhausted. Stop and retry later — no auto-loop.';
    }
    switch (e.code) {
      case 'permission-denied':
        return 'Denied by security rules.';
      case 'unauthenticated':
        return 'Session expired. Sign in again.';
      case 'unavailable':
        return 'Cloud unreachable (offline?). Nothing is proven saved.';
      case 'resource-exhausted':
        return 'Quota exhausted. Try later.';
      default:
        return 'Cloud error: ${e.code}';
    }
  }
}
