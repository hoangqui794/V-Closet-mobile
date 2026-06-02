import 'package:flutter/material.dart';

/// Tập trung tất cả tên route và helper navigation
/// Không import bất kỳ Page widget nào để tránh circular import
class AppRoutes {
  static const String login      = '/login';
  static const String onboarding = '/onboarding';
  static const String main       = '/main';

  static void goToLogin(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(context, login, (r) => false);

  static void goToOnboarding(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(context, onboarding, (r) => false);

  static void goToMain(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(context, main, (r) => false);
}
