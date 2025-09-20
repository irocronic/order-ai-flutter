// lib/models/i_layout_item.dart

import 'package:flutter/material.dart';

// YENİ ARAYÜZ: Tuval üzerindeki tüm sürüklenebilir öğeler (Masa, Element vb.)
// için ortak bir arayüz tanımlar. Bu, provider'daki 'dynamic' kullanımını
// ortadan kaldırarak tip güvenliği sağlar.
abstract class ILayoutItem {
  int? get id;
  // Position ve size gibi ortak özellikler burada tanımlanabilir.
}