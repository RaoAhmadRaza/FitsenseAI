import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../main.dart'
    show
        gUserEmail,
        gUserDisplayName,
        gUserPhotoUrl,
        gUserAge,
        gUserWeightKg,
        gUserHeightCm,
        gUserHeightUnit,
        gUserGender,
        gUserGoals;

import '../../../presentation/widgets/colors.dart';
import 'package:awesome_icons/awesome_icons.dart';
import 'package:horizontal_slider/src/horizontal_slider.dart';
import 'package:animated_weight_picker/animated_weight_picker.dart';
import 'package:msh_checkbox/msh_checkbox.dart';
import 'package:wheel_chooser/wheel_chooser.dart';
import '../../../../core/db/app_database.dart';

enum Gender { male, female }

/// Basic profile screen placeholder. Will be expanded later.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Form controllers and focus nodes
  late TextEditingController _usernameController;
  late FocusNode _usernameFocusNode;

  final double min = 0;
  final double max = 10;
  String selectedValue = '';

  // Lifted profile state
  int _age = gUserAge ?? 20;
  double _weightKg = gUserWeightKg ?? 60;
  double _heightCm = gUserHeightCm ?? 170;
  String _heightUnit = gUserHeightUnit; // 'cm' | 'in'
  Gender _gender = (gUserGender == 'female') ? Gender.female : Gender.male;
  Set<String> _goals = {...gUserGoals};

  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _persistProfile({bool debounce = false}) async {
    final now = DateTime.now();
    if (debounce && now.difference(_lastPersist).inMilliseconds < 500) return;
    _lastPersist = now;
    if (!Hive.isBoxOpen('userBox')) return;
    // sync globals
    gUserDisplayName = _usernameController.text.trim();
    gUserAge = _age;
    gUserWeightKg = _weightKg;
    gUserHeightCm = _heightCm;
    gUserHeightUnit = _heightUnit;
    gUserGender = _gender == Gender.female ? 'female' : 'male';
    gUserGoals = _goals;
    final box = Hive.box('userBox');
    await box.put('profile', {
      'name': gUserDisplayName,
      'avatarUrl': gUserPhotoUrl,
      'age': gUserAge,
      'weightKg': gUserWeightKg,
      'heightCm': gUserHeightCm,
      'heightUnit': gUserHeightUnit,
      'gender': gUserGender,
      'goals': gUserGoals.toList(),
      'updatedAt': now.toIso8601String(),
    });
    // Persist to SQLite so startup rehydrates correctly after hot restart
    try {
      await AppDatabase.saveUserProfileFromGlobals();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // TODO(analytics): profile_opened
    // Hook for analytics provider (e.g., Firebase, Segment). Intentionally not wired yet.
    // Example future call: Analytics.logEvent('profile_opened');
    _usernameController = TextEditingController(text: gUserDisplayName ?? '');
    _usernameFocusNode = FocusNode();
    _usernameController.addListener(() {
      setState(() {}); // live update name text
      _persistProfile(debounce: true);
    });
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _loadExistingProfile() {
    if (!Hive.isBoxOpen('userBox')) return;
    final box = Hive.box('userBox');
    final data = box.get('profile');
    if (data is Map) {
      final name = data['name'] as String?;
      if (name != null && name.isNotEmpty) {
        gUserDisplayName = name;
        if (_usernameController.text.isEmpty) {
          _usernameController.text = name;
        }
      }
      gUserPhotoUrl = data['avatarUrl'] as String? ?? gUserPhotoUrl;
      gUserAge = data['age'] as int? ?? gUserAge;
      gUserWeightKg = (data['weightKg'] as num?)?.toDouble() ?? gUserWeightKg;
      gUserHeightCm = (data['heightCm'] as num?)?.toDouble() ?? gUserHeightCm;
      gUserHeightUnit = data['heightUnit'] as String? ?? gUserHeightUnit;
      gUserGender = data['gender'] as String? ?? gUserGender;
      final goalsList = (data['goals'] as List?)?.cast<String>() ?? [];
      gUserGoals = goalsList.toSet();
      setState(() {
        _age = gUserAge ?? _age;
        _weightKg = gUserWeightKg ?? _weightKg;
        _heightCm = gUserHeightCm ?? _heightCm;
        _heightUnit = gUserHeightUnit;
        _gender = (gUserGender == 'female') ? Gender.female : Gender.male;
        _goals = {...gUserGoals};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = gUserDisplayName ?? 'User';
    final email = gUserEmail ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 39.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Avatar (static)
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          () /* ImageProvider */ {
                                final url = gUserPhotoUrl;
                                if (url == null || url.isEmpty) {
                                  return const AssetImage(
                                    'assets/default_avatar.png',
                                  );
                                }
                                if (url.startsWith('http')) {
                                  return NetworkImage(url);
                                }
                                try {
                                  final f = File(url);
                                  if (f.existsSync()) return FileImage(f);
                                } catch (_) {}
                                return const AssetImage(
                                  'assets/default_avatar.png',
                                );
                              }()
                              as ImageProvider,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final controller = TextEditingController(
                          text: gUserPhotoUrl ?? '',
                        );
                        final result = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('Set Avatar URL or File Path'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'https://... or /path/to/file',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    ctx,
                                    controller.text.trim(),
                                  ),
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                        if (result != null) {
                          setState(() {
                            gUserPhotoUrl = result.isEmpty ? null : result;
                          });
                          await _persistProfile();
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.vibrantRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Name & Email (static)
              Column(
                children: [
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: Colors.black,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
              GenderToggle(
                initial: _gender,
                onChanged: (g) {
                  setState(() => _gender = g);
                  _persistProfile();
                },
              ),
              const SizedBox(height: 40),
              _buildFormField(
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                label: 'Name',
                hint: 'e.g Adam',
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 32),
              // Age Selector with Frosted Glass
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Select your Age',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AgeSelector(
                            initialAge: _age,
                            onChanged: (val) {
                              setState(() => _age = val);
                              _persistProfile();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // ⚡ Height Chooser Section
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        // Keep them outside the builder in a parent stateful widget 👇
                        // (or use ValueNotifier if you want a pure Stateless widget)
                        return _HeightChooser(
                          initialCm: _heightCm,
                          initialUnit: _heightUnit,
                          onChanged: (cm, unit) {
                            setState(() {
                              _heightCm = cm;
                              _heightUnit = unit;
                            });
                            _persistProfile();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              // Weight Selector with Frosted Glass
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Select your Weight (kg)',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedWeightPicker(
                            min: 0,
                            max: 300,
                            subIntervalColor: Colors.black,
                            majorIntervalColor: Colors.black,
                            majorIntervalTextColor: Colors.black,
                            minorIntervalColor: Colors.black,
                            minorIntervalTextColor: Colors.black,
                            dialColor: AppColors.vibrantRed,
                            selectedValueColor: AppColors.vibrantRed,
                            suffixTextColor: AppColors.vibrantRed,
                            onChange: (newValue) {
                              HapticFeedback.lightImpact();
                              final numeric = double.tryParse(
                                newValue.replaceAll(RegExp(r'[^0-9.]'), ''),
                              );
                              setState(() {
                                selectedValue = newValue;
                                if (numeric != null) _weightKg = numeric;
                              });
                              _persistProfile();
                            },
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(height: 28),
                          const Text(
                            "Your Goals",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _GoalsList(
                            selectedGoals: _goals,
                            onChanged: (set) {
                              setState(() => _goals = set);
                              _persistProfile();
                            },
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40.0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  _persistProfile();
                                  // Mark profile as complete for declarative routing.
                                  try {
                                    if (Hive.isBoxOpen('userBox')) {
                                      final box = Hive.box('userBox');
                                      final uid = box.get('uid');
                                      await box.put('profileComplete', true);
                                      if (uid != null) {
                                        await box.put(
                                          'profileCompleteUid',
                                          uid,
                                        );
                                      }
                                    }
                                  } catch (_) {}
                                  // Navigate to home screen (defined in main routes as '/home')
                                  if (mounted) {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/home',
                                      (route) => false,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.vibrantRed,
                                  foregroundColor: AppColors.primaryBlack,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shadowColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// iOS-style form field with bottom underline and floating label
  Widget _buildFormField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? validator,
  }) {
    final effectiveValidator =
        validator ??
        (isRequired
            ? (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.black,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: effectiveValidator,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.black,
          letterSpacing: -0.1,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(prefixIcon, size: 22, color: Colors.black54),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
            letterSpacing: -0.1,
          ),
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black38,
            letterSpacing: -0.1,
          ),
          filled: false,
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  // goal tile builder removed (replaced by _GoalsList)
}

class GenderToggle extends StatelessWidget {
  final Gender initial;
  final ValueChanged<Gender> onChanged;
  const GenderToggle({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gender = initial;
    return Container(
      width: 200,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: gender == Gender.male
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: 100,
              height: 50,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: gender == Gender.male
                    ? Colors.blueAccent
                    : Colors.pinkAccent,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [
                  BoxShadow(
                    color:
                        (gender == Gender.male
                                ? Colors.blueAccent
                                : Colors.pinkAccent)
                            .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onChanged(Gender.male);
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Icon(
                      FontAwesomeIcons.male,
                      color: gender == Gender.male
                          ? Colors.white
                          : Colors.black54,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onChanged(Gender.female);
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Icon(
                      FontAwesomeIcons.female,
                      color: gender == Gender.female
                          ? Colors.white
                          : Colors.black54,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AgeSelector extends StatelessWidget {
  final int initialAge;
  final ValueChanged<int> onChanged;
  const AgeSelector({
    super.key,
    required this.initialAge,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = List<num>.generate(100, (index) => index + 5); // 5..104
    return HorizontalPicker(
      values: values,
      onValueSelected: (value) => onChanged(value.toInt()),
      selectedTextStyle: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      unselectedTextStyle: const TextStyle(fontSize: 16, color: Colors.black54),
      pickerHeight: 100,
      itemExtent: 80,
      diameterRatio: 2.5,
      perspective: 0.003,
      initialSelectedIndex: (initialAge - 5).clamp(0, values.length - 1),
      hapticFeedback: () => HapticFeedback.mediumImpact(),
      selectedItemDecoration: BoxDecoration(
        color: AppColors.vibrantRed,
        borderRadius: BorderRadius.circular(12),
      ),
      unselectedItemDecoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      selectedItemPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      unSelectedItemPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      scrollDuration: const Duration(milliseconds: 300),
    );
  }
}

class _HeightChooser extends StatefulWidget {
  final double initialCm;
  final String initialUnit;
  final void Function(double cm, String unit) onChanged;
  const _HeightChooser({
    required this.initialCm,
    required this.initialUnit,
    required this.onChanged,
  });

  @override
  State<_HeightChooser> createState() => _HeightChooserState();
}

class _HeightChooserState extends State<_HeightChooser> {
  late double _heightCm;
  late String _unit;
  static const int _minCm = 100;
  static const int _maxCm = 250;
  static const int _minIn = 40;
  static const int _maxIn = 100;

  @override
  void initState() {
    super.initState();
    _heightCm = widget.initialCm;
    _unit = widget.initialUnit;
  }

  int _displayValue() => _unit == 'cm'
      ? _heightCm.round().clamp(_minCm, _maxCm)
      : (_heightCm / 2.54).round().clamp(_minIn, _maxIn);

  void _setFromDisplay(int value) {
    if (_unit == 'cm') {
      _heightCm = value.toDouble();
    } else {
      _heightCm = value * 2.54;
    }
    _heightCm = _heightCm.clamp(_minCm.toDouble(), _maxCm.toDouble());
    widget.onChanged(_heightCm, _unit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Select your Height",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('cm'),
              selected: _unit == 'cm',
              selectedColor: AppColors.vibrantRed,
              onSelected: (_) {
                setState(() => _unit = 'cm');
                widget.onChanged(_heightCm, _unit);
              },
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('in'),
              selected: _unit == 'in',
              selectedColor: AppColors.vibrantRed,
              onSelected: (_) {
                setState(() => _unit = 'in');
                widget.onChanged(_heightCm, _unit);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: WheelChooser.integer(
            onValueChanged: (v) {
              setState(() => _setFromDisplay(v));
              HapticFeedback.mediumImpact();
            },
            maxValue: _unit == 'cm' ? _maxCm : _maxIn,
            minValue: _unit == 'cm' ? _minCm : _minIn,
            initValue: _displayValue(),
            step: 1,
            unSelectTextStyle: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            selectTextStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_displayValue()} ' + _unit,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _GoalsList extends StatelessWidget {
  final Set<String> selectedGoals;
  final ValueChanged<Set<String>> onChanged;
  const _GoalsList({required this.selectedGoals, required this.onChanged});

  static const goals = [
    {'label': 'Build Muscle', 'color': Colors.blue},
    {'label': 'Lose Weight', 'color': Colors.pinkAccent},
    {'label': 'Stay Fit', 'color': Colors.green},
    {'label': 'Improve Endurance', 'color': Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < goals.length; i++) ...[
          _GoalItem(
            label: goals[i]['label'] as String,
            color: goals[i]['color'] as Color,
            checked: selectedGoals.contains(goals[i]['label']),
            onToggle: (val) {
              final next = selectedGoals.toSet();
              if (val) {
                next.add(goals[i]['label'] as String);
              } else {
                next.remove(goals[i]['label']);
              }
              onChanged(next);
            },
          ),
          if (i != goals.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GoalItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool checked;
  final ValueChanged<bool> onToggle;
  const _GoalItem({
    required this.label,
    required this.color,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          MSHCheckbox(
            size: 24,
            value: checked,
            colorConfig: MSHColorConfig.fromCheckedUncheckedDisabled(
              checkedColor: color,
            ),
            style: MSHCheckboxStyle.fillScaleCheck,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onToggle(val);
            },
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
