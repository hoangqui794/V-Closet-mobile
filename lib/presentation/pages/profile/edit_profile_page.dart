import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;

  const EditProfilePage({super.key, required this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _userService = GetIt.I<UserApiService>();
  final _localStorage = GetIt.I<AuthLocalStorage>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _countryController;

  String? _gender;
  DateTime? _dateOfBirth;
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile['displayName']?.toString() ?? '');
    _phoneController = TextEditingController(text: profile['phoneNumber']?.toString() ?? '');
    _addressController = TextEditingController(text: profile['address']?.toString() ?? '');
    _heightController = TextEditingController(text: profile['heightCm']?.toString() ?? '');
    _weightController = TextEditingController(text: profile['weightKg']?.toString() ?? '');
    _countryController = TextEditingController(text: profile['country']?.toString() ?? '');

    _gender = profile['gender']?.toString();
    if (_gender != 'Nam' && _gender != 'Nữ' && _gender != 'Khác') {
      _gender = null; // Standardize
    }

    if (profile['dateOfBirth'] != null) {
      try {
        _dateOfBirth = DateTime.parse(profile['dateOfBirth'].toString());
      } catch (_) {}
    }

    _avatarUrl = profile['avatarUrl']?.toString() ?? _localStorage.getUserAvatar();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final newAvatar = await _userService.updateAvatar(File(pickedFile.path));
      
      // Cập nhật local storage
      final userId = _localStorage.getUserId() ?? 0;
      final email = _localStorage.getUserEmail() ?? '';
      final role = _localStorage.getUserRole() ?? 'Customer';
      final name = _nameController.text;
      await _localStorage.saveUser(
        userId: userId,
        email: email,
        displayName: name,
        role: role,
        avatarUrl: newAvatar,
      );

      setState(() {
        _avatarUrl = newAvatar;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final initialDate = _dateOfBirth ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Họ và tên không được để trống.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    try {
      final msg = await _userService.updateMyProfile(
        displayName: displayName,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        heightCm: height,
        weightKg: weight,
        gender: _gender,
        country: _countryController.text.trim(),
        dateOfBirth: _dateOfBirth?.toIso8601String(),
      );

      // Cập nhật local storage tên mới
      final userId = _localStorage.getUserId() ?? 0;
      final email = _localStorage.getUserEmail() ?? '';
      final role = _localStorage.getUserRole() ?? 'Customer';
      await _localStorage.saveUser(
        userId: userId,
        email: email,
        displayName: displayName,
        role: role,
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.replaceAll('Exception: ', ''))),
        );
        Navigator.pop(context, true); // Quay lại trang Profile và thông báo thay đổi thành công
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dateOfBirth != null
        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
        : 'Chọn ngày sinh';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    FadeInDown(
                      child: Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: AppColors.accent,
                              backgroundImage: _avatarUrl != null && _avatarUrl!.startsWith('http')
                                  ? NetworkImage(_avatarUrl!) as ImageProvider
                                  : const AssetImage('assets/images/avatar1.png'),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                height: 36,
                                width: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                  onPressed: _pickAndUploadAvatar,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Họ và tên',
                                hintText: 'Nhập họ tên',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                fillColor: const Color(0xFFFAF9F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Số điện thoại',
                                hintText: 'Nhập số điện thoại',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                fillColor: const Color(0xFFFAF9F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Địa chỉ',
                                hintText: 'Nhập địa chỉ của bạn',
                                prefixIcon: const Icon(Icons.location_on_outlined),
                                fillColor: const Color(0xFFFAF9F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _heightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Chiều cao (cm)',
                                      hintText: 'cm',
                                      prefixIcon: const Icon(Icons.height),
                                      fillColor: const Color(0xFFFAF9F6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextField(
                                    controller: _weightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Cân nặng (kg)',
                                      hintText: 'kg',
                                      prefixIcon: const Icon(Icons.fitness_center_rounded),
                                      fillColor: const Color(0xFFFAF9F6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: 'Giới tính',
                                prefixIcon: const Icon(Icons.wc_rounded),
                                fillColor: const Color(0xFFFAF9F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _gender = val;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _countryController,
                              decoration: InputDecoration(
                                labelText: 'Quốc gia',
                                hintText: 'Nhập quốc gia',
                                prefixIcon: const Icon(Icons.flag_outlined),
                                fillColor: const Color(0xFFFAF9F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Date Picker
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF9F6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cake_outlined, color: Colors.grey),
                                    const SizedBox(width: 12),
                                    Text(
                                      dobText,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _dateOfBirth == null ? Colors.grey : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: _saveChanges,
                              child: const Text('Lưu thay đổi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
