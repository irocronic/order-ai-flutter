// lib/screens/customer_home.dart

import 'package:flutter/material.dart';

class CustomerHome extends StatelessWidget {
  final String token;
  const CustomerHome({Key? key, required this.token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Müşteri Paneli"),
      ),
      body: const Center(
        child: Text("Müşteri Paneline Hoş Geldiniz!"),
      ),
    );
  }
}
