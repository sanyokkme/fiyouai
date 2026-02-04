import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _auth = AuthService();
  String _statusMessage = "Підключення до сервера...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _hasError = false;
      _statusMessage = "Підключення до сервера...";
    });

    bool isConnected = await _auth.checkConnection();

    if (isConnected) {
      // Якщо зв'язок є, переходимо на логін
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _hasError = true;
        _statusMessage = "Не вдалося знайти сервер.\nПеревірте, чи запущено Docker та чи вірна IP-адреса (172.20.10.3).";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade800,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_sync, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (_hasError) ...[
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _connect,
                  child: Text("Спробувати знову"),
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.green.shade900),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}