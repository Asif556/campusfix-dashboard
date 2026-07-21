import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/ui_helpers.dart';
import '../state/complaints_provider.dart';
import '../widgets/gradient_button.dart';
import 'home_shell.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _category;
  final _building = TextEditingController();
  final _floor = TextEditingController();
  final _room = TextEditingController();
  final _description = TextEditingController();
  XFile? _photo;
  bool _submitting = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _building.dispose();
    _floor.dispose();
    _room.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file != null) setState(() => _photo = file);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Could not access the ${source == ImageSource.camera ? 'camera' : 'gallery'}.',
            error: true);
      }
    }
  }

  bool get _valid =>
      _category != null &&
      _building.text.trim().isNotEmpty &&
      _floor.text.trim().isNotEmpty &&
      _room.text.trim().isNotEmpty &&
      _description.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_valid) {
      showSnack(context, 'Please fill in all fields and pick a category.',
          error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<ComplaintsProvider>().create(
            category: _category!,
            building: _building.text.trim(),
            floor: _floor.text.trim(),
            room: _room.text.trim(),
            description: _description.text.trim(),
            photoPath: _photo?.path,
          );
      if (!mounted) return;
      showSnack(context, 'Complaint submitted successfully!');
      _reset();
      HomeScope.of(context).goToTab(2);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    setState(() {
      _category = null;
      _photo = null;
    });
    _building.clear();
    _floor.clear();
    _room.clear();
    _description.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text('Help us improve campus infrastructure by reporting problems.',
                style: TextStyle(
                    fontSize: 13,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            _Section(
              title: 'Select Category',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kCategories.map((c) {
                  final selected = _category == c.label;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: selected ? 2 : 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 17)),
                          const SizedBox(width: 8),
                          Text(c.label,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Location Details',
              icon: Icons.location_on_outlined,
              child: Column(
                children: [
                  _Field(
                    controller: _building,
                    label: 'Building',
                    hint: 'e.g. B1, B2, B3',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _floor,
                          label: 'Floor',
                          hint: 'e.g. 2nd Floor',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          controller: _room,
                          label: 'Room',
                          hint: 'e.g. 2.1',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Describe the Issue',
              child: TextField(
                controller: _description,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      "What's broken, where exactly, and how it affects you...",
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PhotoPicker(
              photo: _photo,
              onPick: _pickPhoto,
              onRemove: () => setState(() => _photo = null),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: _submitting ? 'Submitting...' : 'Submit Complaint',
              icon: Icons.send_rounded,
              loading: _submitting,
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  const _Section({required this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoPicker(
      {required this.photo, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 1.4,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_upload_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(photo != null ? 'Change Photo' : 'Upload Photo (optional)',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(photo!.path),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
