import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StatisticsScreen extends StatefulWidget {
  final String userId;
  const StatisticsScreen({super.key, required this.userId});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.20.10.3:8000/history/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _history = jsonDecode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Моя активність"),
        backgroundColor: Colors.green.shade700,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text("Історія порожня. Зробіть перше фото!"))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Калорії за останні прийоми їжі", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      AspectRatio(
                        aspectRatio: 1.5,
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: _history.asMap().entries.map((e) {
                                  return FlSpot(e.key.toDouble(), 
                                      double.parse(e.value['calories'].toString()));
                                }).toList().reversed.toList(),
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 4,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Останні страви:", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return ListTile(
                              leading: item['image_url'] != null 
                                ? Image.network(item['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                                : const Icon(Icons.fastfood),
                              title: Text("${item['calories']} kcal"),
                              subtitle: Text(item['created_at'].toString().split('T')[0]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}