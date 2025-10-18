import 'package:flutter/material.dart';

class AttendanceStats extends StatelessWidget {
  const AttendanceStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bar_chart, size: 50, color: Colors.deepPurple),
              SizedBox(height: 10),
              Text('Statistiques de présence à venir...',
                  style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}