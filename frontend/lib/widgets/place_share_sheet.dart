import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../services/place_share_service.dart';

Future<void> showPlaceShareSheet(
  BuildContext context,
  MapPlace place, {
  PlaceShareService service = const PlaceShareService(),
}) async {
  final colors = AppColors.of(context);
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.share,
            style: TextStyle(
              color: colors.text,
              fontSize: AppTypography.sectionTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.mapText(
              'Compartilhe somente as informações públicas deste local.',
              'Only public information about this place will be shared.',
            ),
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              final result = await service.share(place);
              if (!context.mounted) return;
              if (result.status == PlaceShareStatus.unavailable) {
                final copied = await service.copy(place);
                if (!context.mounted) return;
                _showFeedback(context, copied.status == PlaceShareStatus.copied
                    ? context.mapText(
                        'Compartilhamento nativo indisponível; informações copiadas.',
                        'Native sharing is unavailable; information copied.',
                      )
                    : context.mapText(
                        'Compartilhamento indisponível e não foi possível copiar.',
                        'Sharing is unavailable and copying failed.',
                      ));
              } else {
                _showFeedback(context, _message(context, result.status));
              }
            },
            icon: const Icon(Icons.share_outlined),
            label: Text(context.l10n.share),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              final result = await service.copy(place);
              if (context.mounted) _showFeedback(context, _message(context, result.status));
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(context.mapText('Copiar informações', 'Copy information')),
          ),
        ],
      ),
    ),
  );
}

String _message(BuildContext context, PlaceShareStatus status) => switch (status) {
  PlaceShareStatus.shared => context.mapText(
      'Compartilhamento concluído pela plataforma.',
      'Sharing completed by the platform.',
    ),
  PlaceShareStatus.dismissed => context.mapText(
      'Compartilhamento cancelado.',
      'Sharing cancelled.',
    ),
  PlaceShareStatus.copied => context.mapText(
      'Informações copiadas.',
      'Information copied.',
    ),
  PlaceShareStatus.copyFailed => context.mapText(
      'Não foi possível copiar as informações.',
      'Could not copy the information.',
    ),
  PlaceShareStatus.error => context.mapText(
      'Não foi possível compartilhar. Tente copiar as informações.',
      'Could not share. Try copying the information.',
    ),
  PlaceShareStatus.unavailable => context.mapText(
      'Compartilhamento nativo indisponível.',
      'Native sharing is unavailable.',
    ),
};

void _showFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
