import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../quiz_controller.dart';
import '../quiz_state.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.uid});
  final String uid;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final QuizController c;

  @override
  void initState() {
    super.initState();
    c = QuizController(uid: widget.uid);
    c.startRound();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  bool _canSignOut(QuizState s) =>
      s != QuizState.submitting &&
      s != QuizState.verifying &&
      s != QuizState.saveUnknown &&
      s != QuizState.verificationUnavailable;

  String _title(QuizState s) => switch (s) {
    QuizState.loading => 'Loading questions…',
    QuizState.playing => 'Question ${c.index + 1} of 10',
    QuizState.readyToSubmit => 'Review',
    QuizState.submitting => 'Saving…',
    QuizState.verifying => 'Verifying with server…',
    QuizState.cloudVerified => 'Cloud verified',
    QuizState.saveUnknown => 'Save status unknown',
    QuizState.verificationUnavailable => 'Verification unavailable',
    QuizState.permissionDenied => 'Denied',
    QuizState.requestError => 'Problem',
    QuizState.authError => 'Sign-in problem',
    QuizState.signedOut => 'Signed out',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_title(c.state)),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: _canSignOut(c.state)
                  ? () => FirebaseAuth.instance.signOut()
                  : null,
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (c.state) {
      case QuizState.loading:
      case QuizState.submitting:
      case QuizState.verifying:
        return const Center(child: CircularProgressIndicator());

      case QuizState.playing:
        return _questionView(context);

      case QuizState.readyToSubmit:
      case QuizState.cloudVerified:
        return _reviewView(context);

      case QuizState.requestError:
      case QuizState.authError:
      case QuizState.permissionDenied:
        return _errorView(
          message: c.message ?? 'Something went wrong.',
          actionLabel: c.state == QuizState.requestError
              ? 'Retry'
              : 'Sign in again',
          onAction: c.state == QuizState.requestError
              ? c.fetch
              : () => FirebaseAuth.instance.signOut(),
        );

      case QuizState.saveUnknown:
      case QuizState.verificationUnavailable:
        return _errorView(
          message: c.message ?? 'Not proven saved.',
          actionLabel: 'Reconcile with server',
          onAction: c.reconcile,
        );

      case QuizState.signedOut:
        return const SizedBox.shrink();
    }
  }

  // ---------------- question ----------------

  Widget _questionView(BuildContext context) {
    final q = c.questions[c.index];
    final picked = c.selections[c.index];
    final answered = picked != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (c.index + 1) / 10),
          const SizedBox(height: 16),
          Text(q.text, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          for (final choice in q.choices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _choiceTile(
                context: context,
                label: choice,
                picked: picked == choice,
                isCorrect: choice == q.correct,
                revealed: answered,
                onTap: answered ? null : () => c.answer(choice),
              ),
            ),
          const Spacer(),
          if (answered)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: picked == q.correct
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    picked == q.correct ? Icons.check_circle : Icons.cancel,
                    color: picked == q.correct
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      picked == q.correct
                          ? 'Correct — 1 point.'
                          : 'Incorrect. Correct answer: ${q.correct}',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: answered ? c.next : null,
            child: Text(c.index == 9 ? 'Finish round' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _choiceTile({
    required BuildContext context,
    required String label,
    required bool picked,
    required bool isCorrect,
    required bool revealed,
    required VoidCallback? onTap,
  }) {
    Color? bg;
    IconData? icon;
    String? tag;

    if (revealed) {
      if (isCorrect) {
        bg = Colors.green.shade100;
        icon = Icons.check_circle;
        tag = 'Correct';
      } else if (picked) {
        bg = Colors.red.shade100;
        icon = Icons.cancel;
        tag = 'Your answer';
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
              Expanded(child: Text(label)),
              if (tag != null)
                Text(tag, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- review ----------------

  Widget _reviewView(BuildContext context) {
    final verified = c.state == QuizState.cloudVerified;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score: ${c.correctCount} / 10',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (c.roundId != null)
                Text(
                  'Round ${c.roundId!.substring(0, 8)}…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (verified)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Cloud verified (server read)'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: 10,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final q = c.questions[i];
              final picked = c.selections[i];
              final ok = picked == q.correct;
              return ListTile(
                leading: Icon(
                  ok ? Icons.check_circle : Icons.cancel,
                  color: ok ? Colors.green : Colors.red,
                ),
                title: Text('${i + 1}. ${q.text}'),
                subtitle: Text(
                  'Your answer: ${picked ?? "—"}\n'
                  'Correct answer: ${q.correct}',
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: verified ? null : c.submit,
                    child: Text(verified ? 'Submitted' : 'Submit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        (c.state == QuizState.readyToSubmit ||
                            c.state == QuizState.cloudVerified)
                        ? c.replay
                        : null,
                    child: const Text('Replay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- error ----------------

  Widget _errorView({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
