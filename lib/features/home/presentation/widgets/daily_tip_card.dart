import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_sizes.dart';

/// Daily Science Tip Card
/// Shows random fun science facts that cycle every 1 minute
class DailyTipCard extends StatefulWidget {
  const DailyTipCard({super.key});

  @override
  State<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends State<DailyTipCard> {
  // Fun science facts for Grade 9 students (Body Systems, Heredity, Ecosystems)
  static const List<String> _scienceTips = [
    // Body Systems / Circulation
    'Your heart beats about 100,000 times per day, pumping around 2,000 gallons of blood through your body!',
    'Blood takes about 20 seconds to circulate through your entire body!',
    'Your lungs contain about 300 million tiny air sacs called alveoli - enough to cover a tennis court if spread out!',
    'The human body contains about 37.2 trillion cells, each working together to keep you alive!',
    'Red blood cells live for about 120 days before being replaced by new ones from your bone marrow!',
    'Your blood vessels, if laid end to end, would stretch about 100,000 kilometers - enough to circle the Earth twice!',
    'The left side of your heart pumps blood to your entire body, while the right side sends it to your lungs!',
    'Your body produces about 200 billion new red blood cells every single day!',
    'The aorta, the largest artery in your body, is almost the diameter of a garden hose!',
    'When you sneeze, air rushes out of your nose at over 160 km/h!',

    // Heredity & Genetics
    'DNA is so long that if you uncoiled all the DNA in your body, it would stretch to the sun and back over 600 times!',
    'Gregor Mendel discovered the basic principles of heredity by studying pea plants in his garden!',
    'Humans share about 99.9% of their DNA with every other person on Earth!',
    'You inherit exactly half of your DNA from your mother and half from your father!',
    'Humans share about 60% of their DNA with bananas - yes, the fruit!',
    'A single gene can have multiple alleles, but you only carry two copies - one from each parent!',
    'Identical twins have the same DNA, but their fingerprints are different due to environmental factors!',
    'The human genome contains about 3 billion base pairs of DNA packed into 23 pairs of chromosomes!',
    'Some traits like blood type follow Mendelian inheritance, while others like skin color involve multiple genes!',
    'Mutations in DNA are the raw material for evolution - they create the variation that natural selection acts on!',

    // Energy in Ecosystems
    'Plants produce the oxygen we breathe through photosynthesis - about 28% of Earth\'s oxygen comes from rainforests!',
    'Energy flows through ecosystems, and only about 10% passes from one level to the next in a food chain!',
    'A single tree can absorb about 22 kilograms of carbon dioxide per year and release oxygen in return!',
    'Decomposers like fungi and bacteria recycle about 90% of all nutrients in an ecosystem!',
    'The sun provides about 173,000 terawatts of energy to Earth continuously - 10,000 times more than all human energy use!',
    'Mangrove forests in the Philippines protect coastlines and serve as nurseries for hundreds of fish species!',
    'A food web is more realistic than a food chain because most organisms eat more than one type of food!',
    'Producers like plants and algae capture only about 1% of the sunlight that reaches them for photosynthesis!',
    'The Philippines is one of 18 mega-biodiverse countries, home to more species per square kilometer than most nations!',
    'Coral reefs cover less than 1% of the ocean floor but support about 25% of all marine species!',

    // General Science
    'Your brain uses about 20% of your body\'s total energy, even though it\'s only 2% of your body weight!',
    'Water makes up about 60% of the adult human body - your brain and heart are about 73% water!',
    'The mitochondria, the powerhouse of the cell, has its own DNA separate from the nucleus!',
    'Capiz, Philippines is known for its rich marine biodiversity and the famous Capiz shell used worldwide!',
    'Photosynthesis and cellular respiration are opposite reactions - one stores energy, the other releases it!',
  ];

  late String _currentTip;
  late final Random _random;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _random = Random();
    _currentTip = _scienceTips[_random.nextInt(_scienceTips.length)];

    // Cycle to a new random tip every 1 minute
    _cycleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTip = _scienceTips[_random.nextInt(_scienceTips.length)];
        });
      }
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with lightbulb emoji
            Row(
              children: [
                const Text(
                  '💡',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  'Did you know?',
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.s12),

            // Tip text with crossfade animation
            Padding(
              padding: const EdgeInsets.only(left: AppSizes.s32 + AppSizes.s4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _currentTip,
                  key: ValueKey<String>(_currentTip),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey600,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
