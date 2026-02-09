import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AppColors.buildBackgroundWithBlurSpots(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.textWhite,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Умови та Політика',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _buildDocumentTile(
                        title: 'Умови користування',
                        icon: Icons.description_outlined,
                        onTap: () {
                          _showDocument(
                            context,
                            'Умови користування',
                            _termsText,
                          );
                        },
                      ),

                      _buildDocumentTile(
                        title: 'Політика конфіденційності',
                        icon: Icons.privacy_tip_outlined,
                        onTap: () {
                          _showDocument(
                            context,
                            'Політика конфіденційності',
                            _privacyText,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.primaryColor,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Інформація',
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ми цінуємо вашу конфіденційність та захищаємо ваші персональні дані. Всі дані зберігаються в зашифрованому вигляді.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cardColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDocument(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(title, style: TextStyle(color: AppColors.textWhite)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              content,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const String _termsText = '''
УМОВИ КОРИСТУВАННЯ

Останнє оновлення: Лютий 2026

1. ПРИЙНЯТТЯ УМОВ
Використовуючи додаток FiYou, ви погоджуєтесь з цими умовами користування.

2. ВИКОРИСТАННЯ ПОСЛУГИ
Додаток надається "як є". Ви несете відповідальність за інформацію, яку вводите.

3. ОБЛІКОВИЙ ЗАПИС
Ви зобов'язані зберігати конфіденційність свого облікового запису.

4. ОБМЕЖЕННЯ ВІДПОВІДАЛЬНОСТІ
Ми не несемо відповідальності за будь-які збитки від використання додатку.

5. ЗМІНИ УМОВ
Ми залишаємо за собою право змінювати ці умови в будь-який час.

Для отримання додаткової інформації, зв'яжіться з нами: support@fiyou.app
''';

  static const String _privacyText = '''
ПОЛІТИКА КОНФІДЕНЦІЙНОСТІ

Останнє оновлення: Лютий 2026

1. ЗБІР ДАНИХ
Ми збираємо наступну інформацію:
- Email адресу
- Дані про здоров'я та харчування
- Статистику використання додатку

2. ВИКОРИСТАННЯ ДАНИХ
Ваші дані використовуються для:
- Надання персоналізованих рекомендацій
- Покращення функціональності додатку
- Відправки нагадувань

3. ЗАХИСТ ДАНИХ
Всі дані зберігаються в зашифрованому вигляді та захищені відповідно до стандартів безпеки.

4. ПЕРЕДАЧА ДАНИХ ТРЕТІМ ОСОБАМ
Ми не передаємо ваші персональні дані третім особам без вашої згоди.

5. ВАШІ ПРАВА
Ви маєте право на доступ, виправлення або видалення своїх даних.

6. ФАЙЛИ COOKIE
Ми використовуємо тільки необхідні технічні файли cookie.

Контакт: support@fiyou.app
''';
}
