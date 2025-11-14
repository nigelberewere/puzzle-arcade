import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../theme_manager.dart';
import '../settings_manager.dart';
import '../services/purchase_service.dart'; // Import purchase service

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  late Future<UserProfile?> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    PurchaseService.instance.initialize(); // Initialize purchase service
  }

  void _loadUserProfile() {
    _userProfileFuture = FirebaseService.instance.getUserProfile();
    _userProfileFuture.then((profile) {
      if (mounted && profile != null) {
        _nameController.text = profile.displayName;
      }
    });
  }

  void _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      await FirebaseService.instance.updateUserDisplayName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated!')),
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final settingsManager = Provider.of<SettingsManager>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // --- Profile Section ---
            Text(
              'Profile',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<UserProfile?>(
                  future: _userProfileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: _saveDisplayName,
                          tooltip: 'Save Name',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
             // --- Ads Section ---
            Text(
              'Advertisements',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: const Text('Remove Ads'),
                  leading: const Icon(Icons.ads_click),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                     PurchaseService.instance.makePurchase('remove_ads');
                  },
                )
              ),
            ),
            // --- Appearance Section ---
            Text(
              'Appearance',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    // ignore: deprecated_member_use
                    RadioListTile<ThemeMode>(
                      title: const Text('System Default'),
                      value: ThemeMode.system,
                      // ignore: deprecated_member_use
                      groupValue: themeManager.themeMode,
                      // ignore: deprecated_member_use
                      onChanged: (value) => themeManager.setThemeMode(value!),
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<ThemeMode>(
                      title: const Text('Light Mode'),
                      value: ThemeMode.light,
                      // ignore: deprecated_member_use
                      groupValue: themeManager.themeMode,
                      // ignore: deprecated_member_use
                      onChanged: (value) => themeManager.setThemeMode(value!),
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark Mode'),
                      value: ThemeMode.dark,
                      // ignore: deprecated_member_use
                      groupValue: themeManager.themeMode,
                      // ignore: deprecated_member_use
                      onChanged: (value) => themeManager.setThemeMode(value!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Color Theme',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppTheme.values.map((themeEnum) {
                    final bool isSelected = themeManager.appTheme == themeEnum;
                    return GestureDetector(
                      onTap: () => themeManager.setThemeColor(themeEnum),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: themeEnum.seedColor,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: themeEnum.seedColor.withValues(alpha:0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Gameplay Section ---
            Text(
              'Gameplay',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Sound Effects'),
                      secondary: const Icon(Icons.volume_up_outlined),
                      value: settingsManager.isSoundEnabled,
                      onChanged: (value) =>
                          settingsManager.setSoundEnabled(value),
                    ),
                    SwitchListTile(
                      title: const Text('Haptic Feedback'),
                      secondary: const Icon(Icons.vibration),
                      value: settingsManager.isHapticsEnabled,
                      onChanged: (value) =>
                          settingsManager.setHapticsEnabled(value),
                    ),
                    SwitchListTile(
                      title: const Text('Instant Error Highlighting'),
                      secondary: const Icon(Icons.error_outline),
                      value: settingsManager.instantErrorChecking,
                      onChanged: (value) =>
                          settingsManager.setInstantErrorChecking(value),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
