import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/subscription_api_service.dart';

class ManualPaymentSheet extends StatefulWidget {
  final SubscriptionPlan plan;
  final VoidCallback onSubmitSuccess;

  const ManualPaymentSheet({
    super.key,
    required this.plan,
    required this.onSubmitSuccess,
  });

  @override
  State<ManualPaymentSheet> createState() => _ManualPaymentSheetState();
}

class _ManualPaymentSheetState extends State<ManualPaymentSheet> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _subscriptionApiService = GetIt.I<SubscriptionApiService>();
  final _picker = ImagePicker();

  File? _selectedImage;
  bool _isUploading = false;
  bool _isSuccess = false;
  String _errorMessage = '';
  final TextEditingController _noteController = TextEditingController();

  late final int _userId;
  late final String _transferContent;
  late final String _qrCodeUrl;

  @override
  void initState() {
    super.initState();
    _userId = _localStorage.getUserId() ?? 0;
    _transferContent = 'VCLOSET ${_userId > 0 ? _userId : "PREMIUM"}';
    
    // Tạo link VietQR động
    final priceInt = widget.plan.price.toInt();
    final accountNameEncoded = Uri.encodeComponent('TRUONG HOANG QUI');
    final addInfoEncoded = Uri.encodeComponent(_transferContent);
    _qrCodeUrl = 'https://img.vietqr.io/image/TPBank-54070904571-compact2.png?amount=$priceInt&addInfo=$addInfoEncoded&accountName=$accountNameEncoded';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể chọn ảnh: $e';
      });
    }
  }

  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn nguồn ảnh biên lai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Thư viện',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _imageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Máy ảnh',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Vui lòng tải lên hình ảnh biên lai chuyển tiền.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = '';
    });

    try {
      // 1. Upload ảnh proof lên server
      final uploadedUrl = await _subscriptionApiService.uploadPaymentProof(_selectedImage!);
      
      // 2. Submit thông tin manual payment lên server
      await _subscriptionApiService.submitManualPayment(
        planId: widget.plan.id,
        proofImageUrl: uploadedUrl,
        userNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      setState(() {
        _isSuccess = true;
        _isUploading = false;
      });

      // Báo về subscription page cập nhật dữ liệu
      widget.onSubmitSuccess();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedPrice = widget.plan.price.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SafeArea(
        child: _isSuccess
            ? _buildSuccessView()
            : _isUploading
                ? _buildLoadingView()
                : _buildFormView(formattedPrice),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          ZoomIn(
            duration: const Duration(milliseconds: 500),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nộp biên lai thành công!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Giao dịch chuyển khoản thủ công của bạn đang chờ Admin xác nhận. Gói Premium sẽ được kích hoạt ngay khi được phê duyệt.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Đang xử lý giao dịch...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vui lòng giữ kết nối mạng ổn định trong lúc tải ảnh biên lai và tạo giao dịch.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFormView(String formattedPrice) {
    return Column(
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title block
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chuyển Khoản Ngân Hàng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ thông báo gói và giá trị cần thanh toán
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plan.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.plan.durationDays != null
                                ? 'Thời hạn: ${widget.plan.durationDays} ngày'
                                : 'Thời hạn: Không giới hạn (Nạp credits)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$formattedPrice đ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Block quét QR VietQR
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Quét mã QR để chuyển khoản nhanh',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _qrCodeUrl,
                            width: 220,
                            height: 220,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 220,
                                height: 220,
                                color: const Color(0xFFFAF9F6),
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 220,
                                height: 220,
                                color: const Color(0xFFFAF9F6),
                                child: const Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.accent),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Chi tiết thông tin CK chuyển tiền
                const Text(
                  'Hoặc chuyển khoản thủ công:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                _bankDetailRow(
                  label: 'Ngân hàng',
                  value: 'TPBank (Ngân hàng Tiên Phong)',
                  canCopy: false,
                ),
                _bankDetailRow(
                  label: 'Số tài khoản',
                  value: '54070904571',
                  canCopy: true,
                  copyValue: '54070904571',
                ),
                _bankDetailRow(
                  label: 'Tên tài khoản',
                  value: 'TRUONG HOANG QUI',
                  canCopy: true,
                  copyValue: 'TRUONG HOANG QUI',
                ),
                _bankDetailRow(
                  label: 'Số tiền chuyển',
                  value: '$formattedPrice đ',
                  canCopy: true,
                  copyValue: widget.plan.price.toInt().toString(),
                ),
                _bankDetailRow(
                  label: 'Nội dung chuyển khoản',
                  value: _transferContent,
                  canCopy: true,
                  copyValue: _transferContent,
                  isHighlighted: true,
                ),
                const SizedBox(height: 24),

                // Upload Biên lai (Bill)
                const Text(
                  'Tải lên ảnh biên lai chuyển tiền:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                
                _buildImagePickerArea(),
                
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 20),

                // Ghi chú thêm (Optional)
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (Không bắt buộc)',
                    hintText: 'Nhập ghi chú hoặc lời nhắn cho admin...',
                    fillColor: Colors.white,
                    filled: true,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Nút Xác nhận
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tôi đã chuyển khoản & Nộp biên lai',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerArea() {
    if (_selectedImage == null) {
      return InkWell(
        onTap: _showImageSourceSelector,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.15),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary.withOpacity(0.5), size: 36),
              const SizedBox(height: 10),
              const Text(
                'Bấm vào để chụp/chọn ảnh biên lai',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Chấp nhận JPG, PNG, WEBP tối đa 10MB',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biên lai đã chọn',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedImage!.path.split(Platform.pathSeparator).last,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () {
              setState(() {
                _selectedImage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _bankDetailRow({
    required String label,
    required String value,
    required bool canCopy,
    String? copyValue,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.secondary.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: AppColors.secondary.withOpacity(0.5), width: 1)
            : Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isHighlighted ? AppColors.primary : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (canCopy && copyValue != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
              onPressed: () => _copyToClipboard(copyValue, label),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
