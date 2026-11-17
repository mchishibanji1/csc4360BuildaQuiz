import 'package:cloud_firestore/cloud_firestore.dart';

import 'dev_flags.dart';

class AttemptCollision implements Exception {
  const AttemptCollision();
}

class VerificationUnavailable implements Exception {
  const VerificationUnavailable();
}

class LostAckInjected implements Exception {
  const LostAckInjected();
}

class AttemptRepository {
  AttemptRepository({required this.uid, required this.roundId});

  final String uid;
  final String roundId; // frozen for the life of this round

  DocumentReference<Map<String, dynamic>> get ref => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('attempts')
      .doc(roundId);

  Future<void> submit({required int correctCount}) async {
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'variant': 'A',
      'categoryId': 9,
      'questionCount': 10,
      'correctCount': correctCount,
      'submittedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, payload);
        return;
      }
      final d = snap.data()!;
      final same =
          d['schemaVersion'] == 1 &&
          d['variant'] == 'A' &&
          d['categoryId'] == 9 &&
          d['questionCount'] == 10 &&
          d['correctCount'] == correctCount;
      if (!same) throw const AttemptCollision();
      // Match → reuse silently; never overwrite.
    });

    // The commit has happened by now.
    if (kInjectLostAck) throw const LostAckInjected();

    await verify(correctCount: correctCount);
  }

  Future<void> verify({required int correctCount}) async {
    final snap = await ref.get(const GetOptions(source: Source.server));

    if (!snap.exists || snap.metadata.hasPendingWrites) {
      throw const VerificationUnavailable();
    }
    final d = snap.data()!;
    final ok =
        d['schemaVersion'] == 1 &&
        d['variant'] == 'A' &&
        d['categoryId'] == 9 &&
        d['questionCount'] == 10 &&
        d['correctCount'] == correctCount &&
        d['submittedAt'] is Timestamp;
    if (!ok) throw const VerificationUnavailable();
  }
}
