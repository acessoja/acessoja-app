import 'package:flutter/material.dart';

import '../app_theme.dart';

class PlaceListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> places = [
    {
      'name': 'UniEVANGÉLICA',
      'distance': '1,2 km',
      'status': 'Aberto',
      'description': 'Universidade com excelentes recursos de acessibilidade.',
    },
    {
      'name': 'Parque da Cidade',
      'distance': '3,4 km',
      'status': 'Aberto',
      'description': 'Local com infraestrutura para todas as idades.',
    },
    {
      'name': 'Shopping Center',
      'distance': '2,1 km',
      'status': 'Fechado',
      'description': 'Shopping acessível e com várias opções de lazer.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Estabelecimentos Salvos',
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    28,
                  ),
                  itemCount: places.length + 1,
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 16 : 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildIntroCard(context);
                    }

                    final place = places[index - 1];
                    return _buildPlaceCard(context, place);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bookmark_rounded,
            color: colors.primaryDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seus locais salvos',
                  style: TextStyle(
                    color: colors.primaryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulte rapidamente os estabelecimentos que você adicionou.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(
    BuildContext context,
    Map<String, dynamic> place,
  ) {
    final colors = AppColors.of(context);
    final name = place['name']?.toString() ?? '';
    final distance = place['distance']?.toString() ?? '';
    final status = place['status']?.toString() ?? '';
    final description = place['description']?.toString() ?? '';
    final isOpen = status.toLowerCase() == 'aberto';

    return Semantics(
      button: true,
      label: '$name. $distance. $status. $description',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/placeDetails',
              arguments: place,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.place_outlined,
                    color: colors.primaryDark,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          _buildMetaChip(
                            context: context,
                            icon: Icons.near_me_outlined,
                            label: distance,
                          ),
                          _buildStatusChip(context, status, isOpen),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.muted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.fieldBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.muted, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status, bool isOpen) {
    final colors = AppColors.of(context);
    final color = isOpen ? colors.success : colors.danger;
    final backgroundColor = isOpen ? colors.successSoft : colors.dangerSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.check_circle_outline : Icons.schedule_outlined,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
