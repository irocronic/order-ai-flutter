// lib/providers/commands.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/business_card_model.dart';
import 'business_card_provider.dart';

abstract class Command {
  final BusinessCardProvider provider;
  Command(this.provider);

  void execute();
  void undo();
}

class ModelUpdateCommand extends Command {
  final BusinessCardModel _oldModel;
  final BusinessCardModel _newModel;

  ModelUpdateCommand(BusinessCardProvider provider, this._oldModel, this._newModel)
      : super(provider);

  @override
  void execute() {
    provider.setCardModelForCommand(_newModel);
  }

  @override
  void undo() {
    provider.setCardModelForCommand(_oldModel);
  }
}

class AddElementCommand extends Command {
  final CardElement _element;

  AddElementCommand(BusinessCardProvider provider, this._element) : super(provider);

  @override
  void execute() {
    final elements = List<CardElement>.from(provider.cardModel.elements)..add(_element);
    final newModel = provider.cardModel.copyWith(elements: elements);
    provider.setCardModelForCommand(newModel);
  }

  @override
  void undo() {
    final elements = List<CardElement>.from(provider.cardModel.elements)
      ..removeWhere((e) => e.id == _element.id);
    final newModel = provider.cardModel.copyWith(elements: elements);
    provider.setCardModelForCommand(newModel);
  }
}

class DeleteElementsCommand extends Command {
  final List<CardElement> _deletedElements;

  DeleteElementsCommand(BusinessCardProvider provider, this._deletedElements)
      : super(provider);

  @override
  void execute() {
    final deletedIds = _deletedElements.map((e) => e.id).toSet();
    final elements = List<CardElement>.from(provider.cardModel.elements)
      ..removeWhere((e) => deletedIds.contains(e.id));
    final newModel = provider.cardModel.copyWith(elements: elements);
    provider.setCardModelForCommand(newModel);
  }

  @override
  void undo() {
    final elements = List<CardElement>.from(provider.cardModel.elements)
      ..addAll(_deletedElements);
    final newModel = provider.cardModel.copyWith(elements: elements);
    provider.setCardModelForCommand(newModel);
  }
}

// GÜNCELLEME: Bu komut artık gradyanı destekliyor.
class UpdateBackgroundColorCommand extends Command {
  final Color _oldStartColor;
  final Color? _oldEndColor;
  final GradientType? _oldGradientType;
  final Color _newStartColor;
  final Color? _newEndColor;
  final GradientType? _newGradientType;

  UpdateBackgroundColorCommand(
      BusinessCardProvider provider,
      this._oldStartColor, this._oldEndColor, this._oldGradientType,
      this._newStartColor, this._newEndColor, this._newGradientType
  ) : super(provider);

  @override
  void execute() {
    final newModel = provider.cardModel.copyWith(
        gradientStartColor: _newStartColor,
        gradientEndColor: _newEndColor,
        gradientType: _newGradientType
    );
    provider.setCardModelForCommand(newModel);
  }

  @override
  void undo() {
    final newModel = provider.cardModel.copyWith(
        gradientStartColor: _oldStartColor,
        gradientEndColor: _oldEndColor,
        gradientType: _oldGradientType
    );
    provider.setCardModelForCommand(newModel);
  }
}