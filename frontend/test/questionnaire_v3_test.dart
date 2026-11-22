import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/accessibility_catalog.dart';
import 'package:flutter_application_1/models/accessibility_survey_v3.dart';
import 'package:flutter_application_1/widgets/resource_answer_fields.dart';

void main() {
  test(
    'generated v3 snapshot contains 47 unique resources in six dimensions',
    () {
      expect(SurveyV3Contract.questions, hasLength(47));
      expect(SurveyV3Contract.ids, hasLength(47));
      expect(AccessibilityCatalog.resources, hasLength(47));
      expect(SurveyV3Contract.dimensions, hasLength(6));
      expect(
        SurveyV3Contract.questions.map((question) => question.id).toSet(),
        AccessibilityCatalog.ids,
      );
    },
  );

  testWidgets(
    'restaurant form shows relevant primary questions and contextual scales',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final answers = <String, String>{};
      final selected = <String>{};
      final details = <String, Map<String, dynamic>>{};

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResourceAnswerFields(
                answers: answers,
                selected: selected,
                details: details,
                category: 'restaurante',
                subcategory: 'restaurante',
                questionnaireVersion: surveyV3Version,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('survey-v3-card-espaco_tranquilo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('survey-v3-card-quarto_adaptado')),
        findsNothing,
      );

      final quietAnswer = find.byKey(
        const ValueKey('survey-v3-espaco_tranquilo-yes'),
      );
      await tester.ensureVisible(quietAnswer);
      await tester.tap(quietAnswer);
      await tester.pumpAndSettle();
      expect(answers['espaco_tranquilo'], 'yes');

      final noiseAnswer = find.byKey(
        const ValueKey('survey-v3-ruido_ambiente-high'),
      );
      await tester.ensureVisible(noiseAnswer);
      await tester.tap(noiseAnswer);
      await tester.pumpAndSettle();
      expect(answers['ruido_ambiente'], 'high');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown category gets general questions and conditionals require confirmation',
    (tester) async {
      final answers = <String, String>{};
      final selected = <String>{};
      final details = <String, Map<String, dynamic>>{};
      final characteristics = <String, bool>{};
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: ResourceAnswerFields(
                  answers: answers,
                  selected: selected,
                  details: details,
                  characteristics: characteristics,
                  category: 'categoria_desconhecida',
                  questionnaireVersion: surveyV3Version,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('survey-v3-card-espaco_tranquilo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('survey-v3-card-quarto_adaptado')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('survey-v3-card-vagas_reservadas')),
        findsNothing,
      );

      final conditionalSection = find.byKey(
        const ValueKey('survey-v3-conditional-characteristics'),
      );
      await tester.ensureVisible(conditionalSection);
      await tester.tap(conditionalSection);
      await tester.pumpAndSettle();
      final parkingAnswer = find.byKey(
        const ValueKey('survey-v3-condition-parking-true'),
      );
      await tester.ensureVisible(parkingAnswer);
      await tester.tap(parkingAnswer);
      await tester.pumpAndSettle();
      expect(characteristics['parking'], isTrue);
      final physicalDimension = find.byKey(
        const ValueKey('survey-v3-dimension-physical'),
      );
      await tester.ensureVisible(physicalDimension);
      await tester.tap(physicalDimension);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('survey-v3-card-vagas_reservadas')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('survey-v3-card-quarto_adaptado')),
        findsNothing,
      );
      final parkingFeature = find.byKey(
        const ValueKey('survey-v3-vagas_reservadas-yes'),
      );
      await tester.ensureVisible(parkingFeature);
      await tester.tap(parkingFeature);
      await tester.pumpAndSettle();
      final parkingAbsent = find.byKey(
        const ValueKey('survey-v3-condition-parking-false'),
      );
      await tester.ensureVisible(parkingAbsent);
      await tester.tap(parkingAbsent);
      await tester.pumpAndSettle();
      expect(characteristics['parking'], isTrue);
      expect(answers['vagas_reservadas'], 'yes');
      final clearParking = find.byKey(
        const ValueKey('survey-v3-vagas_reservadas-clear'),
      );
      await tester.ensureVisible(clearParking);
      await tester.tap(clearParking);
      await tester.pumpAndSettle();
      await tester.ensureVisible(parkingAbsent);
      await tester.tap(parkingAbsent);
      await tester.pumpAndSettle();
      expect(characteristics['parking'], isFalse);
      expect(
        find.byKey(const ValueKey('survey-v3-card-vagas_reservadas')),
        findsNothing,
      );
    },
  );
}
