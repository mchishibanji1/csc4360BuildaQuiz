import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;

import '../dev_flags.dart';
import '../models/question.dart';

class TriviaService {
  static const _url =
      'https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple';

  static Future<List<Question>> fetch() async {
    final res = await http
        .get(Uri.parse(_url))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw QuizException('HTTP ${res.statusCode} — not a valid response.');
    }

    // T03: canned bodies for bad-JSON and non-zero-code injections.
    String body = res.body;
    if (kInjectTriviaFault == InjectTriviaFault.badJson) {
      body = 'this is not json';
    } else if (kInjectTriviaFault == InjectTriviaFault.nonZeroCode) {
      body = '{"response_code":2,"results":[]}';
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const QuizException('Response was not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const QuizException('Response shape is wrong.');
    }

    if (decoded['response_code'] != 0) {
      throw QuizException('API code ${decoded['response_code']} (not 0).');
    }

    var results = decoded['results'];
    if (results is! List) {
      throw const QuizException('Missing results array.');
    }
    if (kInjectTriviaFault == InjectTriviaFault.nineResults &&
        results.length == 10) {
      results = results.sublist(0, 9); // T03 third case
    }
    if (results.length != 10) {
      throw QuizException('Expected 10 questions, got ${results.length}.');
    }

    final unescape = HtmlUnescape();
    final out = <Question>[];
    for (final r in results) {
      if (r is! Map) throw const QuizException('Bad result item.');
      if (r['category'] != 'General Knowledge') {
        throw const QuizException('Wrong category.');
      }
      if (r['difficulty'] != 'easy') {
        throw const QuizException('Wrong difficulty.');
      }
      if (r['type'] != 'multiple') {
        throw const QuizException('Wrong type.');
      }

      final qText = unescape.convert((r['question'] as String).trim());
      final correct = unescape.convert((r['correct_answer'] as String).trim());
      final wrong = (r['incorrect_answers'] as List)
          .map((e) => unescape.convert((e as String).trim()))
          .toList();

      if (qText.isEmpty || correct.isEmpty || wrong.length != 3) {
        throw const QuizException('Question item is incomplete.');
      }
      final choices = [correct, ...wrong]..shuffle();
      if (choices.any((c) => c.isEmpty) || choices.toSet().length != 4) {
        throw const QuizException('Choices empty or duplicated.');
      }
      out.add(Question(text: qText, choices: choices, correct: correct));
    }
    return out;
  }
}
