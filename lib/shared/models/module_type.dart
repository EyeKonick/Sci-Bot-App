import 'package:flutter/material.dart';

/// Module types for the 6-module lesson structure
enum ModuleType {
  /// Module 1: Pre-assessment (Pre-SCI-ntation)
  pre_scintation,
  
  /// Module 2: Hook/Fascination (Fa-SCI-nate)
  fa_scinate,
  
  /// Module 3: Main content (Inve-SCI-tigation)
  inve_scitigation,
  
  /// Module 4: Goal setting (Goal SCI-tting)
  goal_scitting,
  
  /// Module 5: Self-assessment (Self-A-SCI-ssment)
  self_a_scissment,
  
  /// Module 6: Supplementary resources (SCI-pplementary)
  scipplementary;

  /// Get display name for the module type
  String get displayName {
    switch (this) {
      case ModuleType.pre_scintation:
        return 'Pre-SCI-ntation';
      case ModuleType.fa_scinate:
        return 'Fa-SCI-nate';
      case ModuleType.inve_scitigation:
        return 'Inve-SCI-tigation';
      case ModuleType.goal_scitting:
        return 'Goal SCI-tting';
      case ModuleType.self_a_scissment:
        return 'Self-A-SCI-ssment';
      case ModuleType.scipplementary:
        return 'SCI-pplementary';
    }
  }

  /// Get icon for the module type
  IconData get icon {
    switch (this) {
      case ModuleType.pre_scintation:
        return Icons.assignment;
      case ModuleType.fa_scinate:
        return Icons.lightbulb;
      case ModuleType.inve_scitigation:
        return Icons.science;
      case ModuleType.goal_scitting:
        return Icons.flag;
      case ModuleType.self_a_scissment:
        return Icons.quiz;
      case ModuleType.scipplementary:
        return Icons.library_books;
    }
  }

  /// Get the module icon asset path (header variant with "- Copy" suffix)
  String get iconAsset {
    switch (this) {
      case ModuleType.pre_scintation:
        return 'assets/icons/Pre-SCI-ntation - Copy.png';
      case ModuleType.fa_scinate:
        return 'assets/icons/Fa-SCI-nate - Copy.png';
      case ModuleType.inve_scitigation:
        return 'assets/icons/Inve-SCI-tigation - Copy.png';
      case ModuleType.goal_scitting:
        return 'assets/icons/Goal-SCI-tting - Copy.png';
      case ModuleType.self_a_scissment:
        return 'assets/icons/Self-A-SCI-ssment - Copy.png';
      case ModuleType.scipplementary:
        return 'assets/icons/SCI-pplumentary - Copy.png';
    }
  }

  /// Parse from JSON string
  static ModuleType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'pre_scintation':
        return ModuleType.pre_scintation;
      case 'fa_scinate':
        return ModuleType.fa_scinate;
      case 'inve_scitigation':
        return ModuleType.inve_scitigation;
      case 'goal_scitting':
        return ModuleType.goal_scitting;
      case 'self_a_scissment':
        return ModuleType.self_a_scissment;
      case 'scipplementary':
        return ModuleType.scipplementary;
      default:
        throw ArgumentError('Unknown module type: $type');
    }
  }

  /// Convert to JSON string
  String toJson() {
    return toString().split('.').last;
  }
}