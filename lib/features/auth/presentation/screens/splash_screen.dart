import 'package:flutter/material.dart';
import 'package:messenger/shared/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accentBlueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.accentBlue,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
            ),
          ],
        ),
      ),
    );
  }
}
