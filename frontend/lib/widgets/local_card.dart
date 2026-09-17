import 'package:flutter/material.dart';

/// Card de estabelecimento exibido na tela "Explorar Locais".
///
/// Extraído de `explorar_screen.dart` (estava implementado diretamente
/// dentro do `ListView.builder`) para permitir testes de widget isolados.
/// A aparência e o comportamento são idênticos aos originais.
class LocalCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final String Function(String nome) displayNameBuilder;
  final VoidCallback? onRoutePressed;
  final VoidCallback? onDetailsPressed;

  const LocalCard({
    super.key,
    required this.place,
    required this.distanceLabel,
    required this.displayNameBuilder,
    this.onRoutePressed,
    this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final mediaEstrelas = (place['media_estrelas'] ?? 0.0) as num;
    final isOpen = (place['aberto'] ?? true) as bool;
    final nome = (place['nome'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem arredondada na esquerda
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: place['imagem'] != null
                  ? Image.asset(
                      place['imagem'],
                      width: 85,
                      height: 85,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 85,
                          height: 85,
                          color: Colors.grey[200],
                          child: const Icon(Icons.business,
                              color: Colors.grey, size: 36),
                        );
                      },
                    )
                  : Container(
                      width: 85,
                      height: 85,
                      color: Colors.grey[200],
                      child: const Icon(Icons.business,
                          color: Colors.grey, size: 36),
                    ),
            ),
            const SizedBox(width: 12),
            // Informações do local na direita
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayNameBuilder(nome),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$distanceLabel - ${isOpen ? 'Aberto' : 'Fechado'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            Icons.star,
                            size: 13,
                            color: starIndex < mediaEstrelas.round()
                                ? Colors.amber
                                : Colors.grey[300],
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${mediaEstrelas.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botões Verticais à Direita
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onRoutePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CABFF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_rounded, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Rota',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: onDetailsPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: const Color(0xFF4A69FF),
                    minimumSize: const Size(100, 32),
                    side:
                        const BorderSide(color: Color(0xFF4A69FF), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Avaliações',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
