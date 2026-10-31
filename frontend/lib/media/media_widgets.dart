import 'package:flutter/material.dart';

import '../l10n/account_strings.dart';
import '../services/app_http.dart';
import 'media_cache.dart';
import 'media_models.dart';
import 'media_service.dart';
import 'image_selection_service.dart';

String mediaError(
  BuildContext context,
  Object error,
) => switch (error is MediaFailure ? error.status : 0) {
  400 => accountText(
    context,
    'Confira a descrição, os campos e o limite de cinco fotos.',
    'Check the description, fields and five-photo limit.',
  ),
  401 => accountText(
    context,
    'Entre novamente e confira o resultado da operação antes de reenviar.',
    'Sign in again and check the operation before resending.',
  ),
  403 => accountText(
    context,
    'Permissão negada. Confira sua conta ou escolha outra opção de arquivo.',
    'Permission denied. Check your account or choose another file option.',
  ),
  404 => accountText(
    context,
    'A imagem ou avaliação não está mais disponível. Atualize os dados.',
    'The image or review is no longer available. Refresh the data.',
  ),
  409 => accountText(
    context,
    'Há uma operação ou versão diferente. Consulte o resultado e atualize antes de confirmar novamente.',
    'An operation or version changed. Check its result and refresh before confirming again.',
  ),
  413 => accountText(
    context,
    'Use um arquivo de até 5 MiB.',
    'Use a file up to 5 MiB.',
  ),
  422 => accountText(
    context,
    'Use JPEG, PNG ou WebP estático válido, até 24 megapixels. HEIC/HEIF não é aceito; exporte para JPEG ou PNG.',
    'Use valid static JPEG, PNG or WebP up to 24 megapixels. HEIC/HEIF is not accepted; export it as JPEG or PNG.',
  ),
  429 => accountText(
    context,
    'Limite temporário atingido. Aguarde antes de tentar novamente.',
    'Temporary limit reached. Wait before retrying.',
  ),
  _ => accountText(
    context,
    'Não foi possível confirmar o resultado. Consulte a operação antes de reenviar; a seleção continua nesta conta.',
    'Could not confirm the result. Check the operation before resending; the selection remains in this account.',
  ),
};
String photoState(BuildContext context, String state) => switch (state) {
  'approved' => accountText(
    context,
    'Disponível após análise',
    'Available after review',
  ),
  'rejected' => accountText(
    context,
    'Não aprovada. Você pode substituir a imagem ou seu contexto.',
    'Not approved. You can replace the image or its context.',
  ),
  _ => accountText(
    context,
    'Recebida e aguardando análise',
    'Received and awaiting review',
  ),
};
String photoRejectionReason(
  BuildContext context,
  String? reason,
) => switch (reason) {
  'privacy' => accountText(
    context,
    'Remova pessoas, documentos ou dados pessoais da imagem e descrição.',
    'Remove people, documents or personal data from the image and description.',
  ),
  'quality' => accountText(
    context,
    'Escolha uma imagem legível que mostre o recurso.',
    'Choose a clear image showing the feature.',
  ),
  'irrelevant' => accountText(
    context,
    'Escolha uma imagem relacionada à acessibilidade deste local.',
    'Choose an image related to accessibility at this place.',
  ),
  _ => accountText(
    context,
    'Revise a descrição e a relação da imagem com o recurso.',
    'Review the description and how the image relates to the feature.',
  ),
};
Future<SelectedImage?> selectImage(
  BuildContext context,
  ImageSelectionService picker,
  String scope,
) async {
  final source = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                accountText(context, 'Galeria ou arquivo', 'Gallery or file'),
              ),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                accountText(
                  context,
                  'Câmera (se disponível)',
                  'Camera (if available)',
                ),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(accountText(context, 'Cancelar', 'Cancel')),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) {
    return null;
  }
  return picker.pick(scope: scope, camera: source);
}

class SelectedImagePreview extends StatefulWidget {
  const SelectedImagePreview({super.key, required this.file});
  final SelectedImage file;
  @override
  State<SelectedImagePreview> createState() => _SelectedImagePreviewState();
}

class _SelectedImagePreviewState extends State<SelectedImagePreview> {
  late ImageProvider _provider;
  @override
  void initState() {
    super.initState();
    _provider = MediaSessionCache.track(
      ResizeImage.resizeIfNeeded(800, 800, MemoryImage(widget.file.bytes)),
    );
  }

  @override
  void didUpdateWidget(covariant SelectedImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      MediaSessionCache.discard(_provider);
      _provider = MediaSessionCache.track(
        ResizeImage.resizeIfNeeded(800, 800, MemoryImage(widget.file.bytes)),
      );
    }
  }

  @override
  void dispose() {
    MediaSessionCache.discard(_provider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    child: Image(
      image: _provider,
      fit: BoxFit.contain,
      semanticLabel: accountText(
        context,
        'Prévia local: ainda não enviada',
        'Local preview: not uploaded yet',
      ),
      errorBuilder: (_, error, stack) => Text(
        accountText(
          context,
          'Prévia indisponível. Confira o arquivo antes de enviar.',
          'Preview unavailable. Check the file before submitting.',
        ),
      ),
    ),
  );
}

class PrivateImage extends StatefulWidget {
  const PrivateImage({
    super.key,
    required this.path,
    required this.revision,
    required this.description,
    this.height = 160,
    this.service = const MediaService(),
  });
  final String path, revision, description;
  final double height;
  final MediaService service;
  @override
  State<PrivateImage> createState() => _PrivateImageState();
}

class _PrivateImageState extends State<PrivateImage> {
  ImageProvider? _provider;
  bool _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.revision != widget.revision) {
      _reload();
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_reload);
    MediaSessionCache.discard(_provider);
    super.dispose();
  }

  void _reload() {
    MediaSessionCache.discard(_provider);
    _provider = null;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _failed = false);
    try {
      final bytes = await widget.service.bytes(widget.path);
      if (mounted && generation == _generation) {
        setState(() => _provider = MediaSessionCache.track(MemoryImage(bytes)));
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: Semantics(
      image: true,
      label: widget.description,
      child: _failed
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined),
                Text(
                  accountText(
                    context,
                    'Imagem indisponível',
                    'Image unavailable',
                  ),
                ),
                TextButton(
                  onPressed: _reload,
                  child: Text(
                    accountText(context, 'Tentar novamente', 'Try again'),
                  ),
                ),
              ],
            )
          : _provider == null
          ? const Center(child: CircularProgressIndicator())
          : Image(
              image: _provider!,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, error, stack) => Text(
                accountText(
                  context,
                  'Não foi possível exibir a imagem.',
                  'Could not display the image.',
                ),
              ),
            ),
    ),
  );
}
