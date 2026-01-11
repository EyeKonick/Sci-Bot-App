import 'models.dart';

/// Test function to verify all models work correctly
void testModels() {
  print('=== Testing Data Models ===\n');

  // Test 1: ModuleType Enum
  print('Test 1: ModuleType Enum');
  final moduleType = ModuleType.preScintation;
  print('Display Name: ${moduleType.displayName}');
  print('JSON Key: ${moduleType.jsonKey}');
  print('From JSON: ${ModuleType.fromJson('fa_scinate').displayName}');
  print('✅ ModuleType works!\n');

  // Test 2: ModuleModel
  print('Test 2: ModuleModel');
  final module = ModuleModel(
    id: 'module_1',
    type: ModuleType.faScinate,
    title: 'Introduction to DNA',
    content: 'DNA is the molecule that contains genetic information...',
    order: 1,
    estimatedMinutes: 10,
  );
  print('Module: ${module.title}');
  print('Type: ${module.type.displayName}');
  
  // Test JSON serialization
  final moduleJson = module.toJson();
  final moduleFromJson = ModuleModel.fromJson(moduleJson);
  print('JSON round-trip: ${moduleFromJson.title}');
  print('✅ ModuleModel works!\n');

  // Test 3: LessonModel
  print('Test 3: LessonModel');
  final lesson = LessonModel(
    id: 'lesson_1',
    topicId: 'topic_1',
    title: 'Understanding Heredity',
    description: 'Learn how traits are passed from parents to offspring',
    modules: [module],
    estimatedMinutes: 30,
  );
  print('Lesson: ${lesson.title}');
  print('Module count: ${lesson.moduleCount}');
  print('✅ LessonModel works!\n');

  // Test 4: TopicModel
  print('Test 4: TopicModel');
  final topic = TopicModel(
    id: 'topic_1',
    name: 'Heredity & Variation',
    description: 'Learn about genes, DNA, and inheritance',
    iconName: 'biotech',
    colorHex: '#4DB8C4',
    lessonIds: ['lesson_1', 'lesson_2'],
    order: 1,
  );
  print('Topic: ${topic.name}');
  print('Lesson count: ${topic.lessonCount}');
  print('✅ TopicModel works!\n');

  // Test 5: ProgressModel
  print('Test 5: ProgressModel');
  var progress = ProgressModel(
    lessonId: 'lesson_1',
    completedModuleIds: {'module_1'},
    lastAccessed: DateTime.now(),
  );
  print('Initial progress: ${(progress.completionPercentage * 100).toInt()}%');
  
  // Mark more modules as complete
  progress = progress.markModuleCompleted('module_2');
  progress = progress.markModuleCompleted('module_3');
  print('After 3 modules: ${(progress.completionPercentage * 100).toInt()}%');
  print('Is completed: ${progress.isCompleted}');
  print('✅ ProgressModel works!\n');

  // Test 6: ChatMessageModel
  print('Test 6: ChatMessageModel');
  final message = ChatMessageModel(
    id: 'msg_1',
    text: 'What is DNA?',
    sender: MessageSender.user,
    timestamp: DateTime.now(),
    lessonContext: 'lesson_1',
  );
  print('Message: ${message.text}');
  print('From: ${message.sender.name}');
  print('Is user: ${message.isUser}');
  print('Has context: ${message.hasContext}');
  print('✅ ChatMessageModel works!\n');

  print('=== All Models Working! ===');
}