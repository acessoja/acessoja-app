import 'package:flutter/material.dart';

/// Presentation only: persisted category codes and API filters remain intact.
class PlaceCategoryVisual {
  final IconData icon;
  final Color color;
  final String portuguese;
  final String english;
  const PlaceCategoryVisual(
    this.icon,
    this.color,
    this.portuguese,
    this.english,
  );
}

const placeCategoryVisuals = <String, PlaceCategoryVisual>{
  'restaurante': PlaceCategoryVisual(
    Icons.restaurant,
    Color(0xFFB45309),
    'Restaurante',
    'Restaurant',
  ),
  'cafeteria': PlaceCategoryVisual(
    Icons.local_cafe_outlined,
    Color(0xFF7C3AED),
    'Cafeteria',
    'Cafe',
  ),
  'supermercado': PlaceCategoryVisual(
    Icons.shopping_cart_outlined,
    Color(0xFF15803D),
    'Supermercado',
    'Supermarket',
  ),
  'farmacia': PlaceCategoryVisual(
    Icons.local_pharmacy_outlined,
    Color(0xFFBE123C),
    'Farmácia',
    'Pharmacy',
  ),
  'saude': PlaceCategoryVisual(
    Icons.medical_services_outlined,
    Color(0xFF0369A1),
    'Saúde',
    'Healthcare',
  ),
  'educacao': PlaceCategoryVisual(
    Icons.school_outlined,
    Color(0xFF4338CA),
    'Educação',
    'Education',
  ),
  'loja': PlaceCategoryVisual(
    Icons.storefront_outlined,
    Color(0xFF185ABD),
    'Loja',
    'Shop',
  ),
  'parque': PlaceCategoryVisual(
    Icons.park_outlined,
    Color(0xFF047857),
    'Parque',
    'Park',
  ),
  'banco': PlaceCategoryVisual(
    Icons.account_balance_outlined,
    Color(0xFF475569),
    'Banco',
    'Bank',
  ),
  'publico': PlaceCategoryVisual(
    Icons.domain_outlined,
    Color(0xFF0F766E),
    'Serviço público',
    'Public service',
  ),
  'outros': PlaceCategoryVisual(
    Icons.place_outlined,
    Color(0xFF185ABD),
    'Estabelecimento',
    'Establishment',
  ),
};
const unknownPlaceCategory = PlaceCategoryVisual(
  Icons.place_outlined,
  Color(0xFF475569),
  'Categoria não informada',
  'Category not reported',
);

PlaceCategoryVisual categoryVisual(String code) =>
    placeCategoryVisuals[code] ?? unknownPlaceCategory;
