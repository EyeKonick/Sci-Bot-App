import 'package:flutter/material.dart';

/// Model for onboarding page content
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isCustomIcon;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.isCustomIcon = false,
  });
}