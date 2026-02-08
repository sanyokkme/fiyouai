import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StoryViewScreen extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Час показу однієї сторіз
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _animController.forward();
    } else {
      Navigator.pop(context); // Закриваємо, якщо сторіз закінчились
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward(); // Просто перезапускаємо першу
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _prevStory(); // Ліва третина екрана - назад
    } else {
      _nextStory(); // Решта - вперед
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPress: () =>
            _animController.stop(), // Пауза при довгому натисканні
        onLongPressUp: () => _animController.forward(), // Продовження
        child: Stack(
          children: [
            // PageView для слайдів
            PageView.builder(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Блокуємо свайп (керуємо тапами)
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      story['image_url'] ?? "",
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryColor,
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    // Градієнт для тексту
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    // Текст
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Text(
                        story['title'] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              },
            ),

            // Прогрес-бари зверху
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(widget.stories.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildProgressBar(index),
                    ),
                  );
                }),
              ),
            ),

            // Кнопка закриття
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < _currentIndex) {
      // Вже переглянуто (повний)
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (index == _currentIndex) {
      // Поточний (анімований)
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: _animController.value,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          );
        },
      );
    } else {
      // Майбутній (порожній)
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
  }
}
