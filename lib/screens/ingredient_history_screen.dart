// lib/screens/ingredient_history_screen.dart (YENİ DOSYA)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/ingredient_stock_movement.dart';
import '../services/ingredient_service.dart';
import '../services/user_session.dart';

class IngredientHistoryScreen extends StatefulWidget {
  final int ingredientId;
  final String ingredientName;

  const IngredientHistoryScreen({
    Key? key,
    required this.ingredientId,
    required this.ingredientName,
  }) : super(key: key);

  @override
  _IngredientHistoryScreenState createState() => _IngredientHistoryScreenState();
}

class _IngredientHistoryScreenState extends State<IngredientHistoryScreen> {
  late Future<List<IngredientStockMovement>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = IngredientService.fetchIngredientHistory(UserSession.token, widget.ingredientId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ingredientHistoryTitle(widget.ingredientName), style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.9), Colors.blue.shade400.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<IngredientStockMovement>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.errorGeneral(snapshot.error.toString()), style: const TextStyle(color: Colors.orangeAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text(l10n.ingredientHistoryNoMovements, style: const TextStyle(color: Colors.white70)));
            }

            final movements = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: movements.length,
              itemBuilder: (context, index) {
                final move = movements[index];
                final isPositive = move.quantityChange >= 0;
                final changeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;

                return Card(
                  color: Colors.white.withOpacity(0.9),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: changeColor.withOpacity(0.15),
                      child: Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: changeColor),
                    ),
                    title: Text(
                      '${move.movementTypeDisplay}: ${isPositive ? "+" : ""}${move.quantityChange.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: changeColor),
                    ),
                    subtitle: Text(
                      '${l10n.ingredientHistoryStockBefore}: ${move.quantityBefore.toStringAsFixed(2)}\n'
                      '${l10n.ingredientHistoryStockAfter}: ${move.quantityAfter.toStringAsFixed(2)}\n'
                      '${DateFormat('dd.MM.yyyy HH:mm').format(move.timestamp)} - ${move.userUsername ?? l10n.systemUser}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}