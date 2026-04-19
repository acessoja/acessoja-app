import 'package:flutter/material.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PlaceDetailScreen({required this.place, Key? key}) : super(key: key);

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final List<Map<String, dynamic>> comments = []; // Lista de comentários
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 0; // Estrelas selecionadas pelo usuário

double get averageRating {
  if (comments.isEmpty) return 0.0;
  final totalStars = comments.fold<int>(0, (sum, comment) => sum + (comment['stars'] as int));
  return totalStars / comments.length;
}


  void addComment(String userName, String commentText, int stars) {
    setState(() {
      comments.add({
        'user': userName,
        'text': commentText,
        'stars': stars,
      });
      _commentController.clear();
      _selectedStars = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome do estabelecimento
            Text(
              widget.place['name'],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Estrelas e média de avaliações
            Row(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 32,
                      color: index < averageRating.round()
                          ? Colors.amber
                          : Colors.grey[300],
                    );
                  }),
                ),
                SizedBox(width: 8),
                Text(
                  averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Quantidade de avaliações
            Text(
              '${comments.length} avaliações',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),

            // Lista de comentários
            Expanded(
              child: comments.isEmpty
                  ? Center(
                      child: Text(
                        'Seja o primeiro a comentar!',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(
                              comment['user'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      Icons.star,
                                      size: 16,
                                      color: starIndex < comment['stars']
                                          ? Colors.amber
                                          : Colors.grey[300],
                                    );
                                  }),
                                ),
                                SizedBox(height: 4),
                                Text(comment['text']),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 32),

            // Campo para adicionar comentário
            Text(
              'Qual sua nota?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStars = index + 1;
                    });
                  },
                  child: Icon(
                    Icons.star,
                    size: 32,
                    color: index < _selectedStars ? Colors.amber : Colors.grey,
                  ),
                );
              }),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Gostaria de adicionar comentários?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),

            // Botão de confirmar
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_commentController.text.isNotEmpty && _selectedStars > 0) {
                    addComment('leo', _commentController.text, _selectedStars);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Por favor, adicione um comentário e selecione uma avaliação!',
                        ),
                      ),
                    );
                  }
                },
                child: Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
