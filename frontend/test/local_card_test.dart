import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/local_card.dart';

void main() {
  final place = <String, dynamic>{
    'nome': 'UniEVANGÉLICA',
    'distancia': 1.2,
    'aberto': true,
    'media_estrelas': 4.0,
  };

  Widget buildCard({
    Map<String, dynamic>? overridePlace,
    VoidCallback? onRoute,
    VoidCallback? onDetails,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LocalCard(
          place: overridePlace ?? place,
          distanceLabel: '1,2 km',
          displayNameBuilder: (nome) => nome,
          onRoutePressed: onRoute,
          onDetailsPressed: onDetails,
        ),
      ),
    );
  }

  testWidgets('exibe nome, distância e status do local', (tester) async {
    await tester.pumpWidget(buildCard());

    expect(find.text('UniEVANGÉLICA'), findsOneWidget);
    expect(find.text('1,2 km - Aberto'), findsOneWidget);
  });

  testWidgets('exibe "Fechado" quando o local não está aberto', (tester) async {
    await tester.pumpWidget(buildCard(
      overridePlace: {...place, 'aberto': false},
    ));

    expect(find.text('1,2 km - Fechado'), findsOneWidget);
  });

  testWidgets('exibe ícone de estabelecimento quando não há imagem cadastrada',
      (tester) async {
    await tester.pumpWidget(buildCard());

    expect(find.byIcon(Icons.business), findsOneWidget);
  });

  testWidgets('exibe as estrelas preenchidas de acordo com a média do local',
      (tester) async {
    await tester.pumpWidget(buildCard());

    final stars = tester.widgetList<Icon>(find.byIcon(Icons.star)).toList();
    expect(stars.length, 5);

    final filled = stars.where((icon) => icon.color == Colors.amber).length;
    expect(filled, 4);
  });

  testWidgets('aciona o callback de Rota ao tocar no botão Rota', (tester) async {
    var routeTapped = false;
    await tester.pumpWidget(buildCard(onRoute: () => routeTapped = true));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Rota'));
    await tester.pump();

    expect(routeTapped, isTrue);
  });

  testWidgets('aciona o callback de Avaliações ao tocar no botão Avaliações',
      (tester) async {
    var detailsTapped = false;
    await tester.pumpWidget(buildCard(onDetails: () => detailsTapped = true));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Avaliações'));
    await tester.pump();

    expect(detailsTapped, isTrue);
  });
}
