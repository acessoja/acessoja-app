import 'package:flutter/material.dart';

/// Presentation only: persisted category codes and API filters remain intact.
class PlaceCategoryVisual {
  final IconData icon;
  final String portuguese;
  final String english;
  const PlaceCategoryVisual(this.icon, this.portuguese, this.english);
}

const placeCategoryVisuals = <String, PlaceCategoryVisual>{
  'restaurante': PlaceCategoryVisual(Icons.restaurant, 'Restaurante', 'Restaurant'),
  'cafeteria': PlaceCategoryVisual(Icons.local_cafe_outlined, 'Cafeteria', 'Cafe'),
  'supermercado': PlaceCategoryVisual(Icons.shopping_cart_outlined, 'Supermercado', 'Supermarket'),
  'farmacia': PlaceCategoryVisual(Icons.local_pharmacy_outlined, 'Farmácia', 'Pharmacy'),
  'saude': PlaceCategoryVisual(Icons.medical_services_outlined, 'Saúde', 'Healthcare'),
  'educacao': PlaceCategoryVisual(Icons.school_outlined, 'Educação', 'Education'),
  'loja': PlaceCategoryVisual(Icons.storefront_outlined, 'Loja', 'Shop'),
  'parque': PlaceCategoryVisual(Icons.park_outlined, 'Parque', 'Park'),
  'banco': PlaceCategoryVisual(Icons.account_balance_outlined, 'Banco', 'Bank'),
  'publico': PlaceCategoryVisual(Icons.domain_outlined, 'Serviço público', 'Public service'),
  'outros': PlaceCategoryVisual(Icons.place_outlined, 'Estabelecimento', 'Establishment'),
};
const unknownPlaceCategory = PlaceCategoryVisual(
    Icons.place_outlined, 'Categoria não informada', 'Category not reported');

PlaceCategoryVisual categoryVisual(String code) =>
    placeCategoryVisuals[code] ?? unknownPlaceCategory;
