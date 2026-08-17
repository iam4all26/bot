import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/withdrawal_pin_modal.dart';
import '../../widgets/bank_selector_sheet.dart';
import 'set_pin_screen.dart';

class MarketCashOutScreen extends StatefulWidget {
  const MarketCashOutScreen({super.key});

  @override
  State<MarketCashOutScreen> createState() => _MarketCashOutScreenState();
}

class _MarketCashOutScreenState extends State<MarketCashOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cryptoAmountController = TextEditingController();
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResolvingAccount = false;
  bool _hasPin = false;

  String _selectedAssetKey = 'USDT';
  String? _selectedBankCode;
  String? _resolvedAccountName;
  String? _accountResolutionError;

  List<dynamic> _assets = [];
  Map<String, dynamic> _balances = {};
  List<dynamic> _banks = [];
  Timer? _debounceTimer;

  static const double _nairaWithdrawalFee = 30.0; 

  Color _getAssetColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'SOL': return const Color(0xFF10B981);
      case 'BNB': return const Color(0xFFF59E0B);
      case 'ETH': return const Color(0xFF3B82F6);
      case 'USDT': return const Color(0xFF14B8A6);
      default: return const Color(0xFF8B5CF6);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cryptoAmountController.dispose();
    _fiatAmountController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    final results = await Future.wait([
      api.checkPinStatus(),
      api.fetchMarketHub(),
      api.getNigerianBanks(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['status'] == 'success' && results[0]['data'] != null) {
          _hasPin = results[0]['data']['has_pin'] ?? false;
        }
        if (results[1]['status'] == 'success' && results[1]['data'] != null) {
          _assets = results[1]['data']['assets'] ?? [];
          _balances = results[1]['data']['balances'] ?? {};
        }
        if (results[2]['status'] == 'success' && results[2]['data'] != null) {
          _banks = results[2]['data'] ?? [];
        }
      });
    }
  }

  Map<String, dynamic>? _getSelectedAssetData() {
    for (var a in _assets) {
      if (a['asset'] == _selectedAssetKey) return a;
    }
    return _assets.isNotEmpty ? _assets.first : null;
  }

  double _getAvailableBalance() {
    final assetData = _getSelectedAssetData();
    if (assetData == null) return 0.0;

    final String? chain = assetData['chain'];
    final bool isUsdt = chain == null || _selectedAssetKey == 'USDT';

    if (isUsdt) {
      return double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;
    }

    final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
    return double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0;
  }

  void _onCryptoInputChanged(String value) {
    final cryptoVal = double.tryParse(value.trim()) ?? 0.0;
    final assetData = _getSelectedAssetData();
    final double sellRate = double.tryParse(assetData?['ngn_sell_rate']?.toString() ?? '0') ?? 0.0;

    final fiatVal = cryptoVal * sellRate;
    _fiatAmountController.text = fiatVal > 0 ? fiatVal.toStringAsFixed(2) : '';
    setState(() {});
  }

  void _onFiatInputChanged(String value) {
    final fiatVal = double.tryParse(value.trim()) ?? 0.0;
    final assetData = _getSelectedAssetData();
    final double sellRate = double.tryParse(assetData?['ngn_sell_rate']?.toString() ?? '0') ?? 0.0;

    if (sellRate > 0) {
      final cryptoVal = fiatVal / sellRate;
      _cryptoAmountController.text = cryptoVal > 0 ? cryptoVal.toStringAsFixed(6) : '';
    }
    setState(() {});
  }

  void _setMaxAmount() {
    final balance = _getAvailableBalance();
    _cryptoAmountController.text = balance.toString();
    _onCryptoInputChanged(balance.toString());
  }

  void _onAccountNumberChanged(String val) {
    _debounceTimer?.cancel();
    final accNum = val.trim();

    if (accNum.length == 10 && _selectedBankCode != null) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _resolveAccount(accNum, _selectedBankCode!);
      });
    } else {
      setState(() {
        _resolvedAccountName = null;
        _accountResolutionError = null;
      });
    }
  }

  Future<void> _resolveAccount(String accountNumber, String bankCode) async {
    setState(() {
      _isResolvingAccount = true;
      _accountResolutionError = null;
      _resolvedAccountName = null;
    });

    final api = context.read<ApiService>();
    final res = await api.resolveBankAccount(
      accountNumber: accountNumber,
      bankCode: bankCode,
    );

    if (mounted) {
      setState(() {
        _isResolvingAccount = false;
        if (res['status'] == 'success' && res['data'] != null) {
          _resolvedAccountName = res['data']['account_name'];
        } else {
          _accountResolutionError = res['message'] ?? 'Could not resolve bank account details.';
        }
      });
    }
  }

  Future<void> _openBankSelector() async {
    final selected = await showBankSelectorSheet(
      context,
      banks: _banks,
      currentCode: _selectedBankCode,
    );
    if (selected == null) return;

    setState(() {
      _selectedBankCode = selected['code']?.toString();
      _resolvedAccountName = null;
    });
    if (_accountNumberController.text.trim().length == 10 && _selectedBankCode != null) {
      _resolveAccount(_accountNumberController.text.trim(), _selectedBankCode!);
    }
  }

  String _numberToWords(double amount) {
    if (amount <= 0) return '';
    final int integerPart = amount.floor();
    final int koboPart = ((amount - integerPart) * 100).round();

    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertLessThanThousand(int n) {
      if (n < 20) return units[n];
      if (n < 100) return tens[n ~/ 10] + (n % 10 != 0 ? ' ${units[n % 10]}' : '');
      return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${convertLessThanThousand(n % 100)}' : ''}';
    }

    String convert(int n) {
      if (n == 0) return 'Zero';
      if (n < 1000) return convertLessThanThousand(n);
      if (n < 1000000) return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
      if (n < 1000000000) return '${convert(n ~/ 1000000)} Million${n % 1000000 != 0 ? ' ${convert(n % 1000000)}' : ''}';
      return '${convert(n ~/ 1000000000)} Billion${n % 1000000000 != 0 ? ' ${convert(n % 1000000000)}' : ''}';
    }

    String words = '${convert(integerPart)} Naira';
    if (koboPart > 0) {
      words += ' and ${convert(koboPart)} Kobo';
    }
    return '$words Only';
  }

  Future<void> _handleCashOutClick() async {
    if (!_hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set up a withdrawal PIN first.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.warning(context),
        ),
      );

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
      if (result == true) _fetchInitialData();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_resolvedAccountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please resolve a valid bank account name first.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    final amount = double.tryParse(_cryptoAmountController.text.trim()) ?? 0.0;
    final balance = _getAvailableBalance();

    if (amount <= 0 || amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Amount exceeds available balance.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    final String? pin = await WithdrawalPinModal.show(
      context,
      title: 'Authorize Cash Out',
      subtitle: 'Enter 4-digit PIN to release funds to $_resolvedAccountName.',
    );

    if (pin == null || pin.length != 4) return;

    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();

    final res = await api.withdrawNaira(
      asset: _selectedAssetKey,
      amount: amount,
      bankCode: _selectedBankCode!,
      accountNumber: _accountNumberController.text.trim(),
      accountName: _resolvedAccountName!,
      pin: pin,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      final bool isSuccess = res['status'] == 'success';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? (isSuccess ? 'Cash out initiated!' : 'Withdrawal failed'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: isSuccess ? AppTheme.success(context) : AppTheme.danger(context),
        ),
      );

      if (isSuccess) {
        _cryptoAmountController.clear();
        _fiatAmountController.clear();
        _accountNumberController.clear();
        setState(() {
          _resolvedAccountName = null;
        });
        _fetchInitialData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    final double availableBalance = _getAvailableBalance();
    final double typedFiat = double.tryParse(_fiatAmountController.text.trim()) ?? 0.0;
    final String amountInWords = _numberToWords(typedFiat);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'CASH OUT TO BANK',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT ASSET TO SELL',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: _assets.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var a = entry.value;

                          final String symbol = a['symbol'] ?? 'USDT';
                          final String? chain = a['chain'];
                          final bool isSelected = symbol == _selectedAssetKey;
                          final bool isUsdt = chain == null || symbol == 'USDT';

                          final Color assetColor = _getAssetColor(symbol);

                          final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
                          final double usdtTotal = double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;
                          final double balance = isUsdt
                              ? usdtTotal
                              : (double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0);

                          return Column(
                            children: [
                              if (idx > 0)
                                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedAssetKey = symbol;
                                    _cryptoAmountController.clear();
                                    _fiatAmountController.clear();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? PhosphorIcons.checkCircleFill : PhosphorIcons.circle,
                                        color: isSelected ? theme.primaryColor : theme.colorScheme.outline,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 14),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: assetColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: assetColor.withOpacity(0.2)),
                                        ),
                                        child: Image.network(
                                          'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/${symbol.toLowerCase()}.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                symbol.substring(0, 1).toUpperCase(),
                                                style: TextStyle(
                                                  color: assetColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        symbol,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${balance.toStringAsFixed(isUsdt ? 2 : 4)} $symbol',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'AVAILABLE BALANCE',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  side: BorderSide(color: theme.primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _setMaxAmount,
                                child: Text(
                                  'USE MAX',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${availableBalance.toStringAsFixed(4)} $_selectedAssetKey',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cryptoAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Amount ($_selectedAssetKey)',
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: _onCryptoInputChanged,
                                  validator: (val) {
                                    final amt = double.tryParse(val?.trim() ?? '');
                                    if (amt == null || amt <= 0) return 'Enter amount';
                                    if (amt > availableBalance) return 'Exceeds balance';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _fiatAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    color: AppTheme.success(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Amount (₦)',
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: _onFiatInputChanged,
                                ),
                              ),
                            ],
                          ),

                          if (amountInWords.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.success(context).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.success(context).withOpacity(0.2)),
                              ),
                              child: Text(
                                amountInWords,
                                style: TextStyle(
                                  color: AppTheme.success(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Processing Fee:',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '₦${_nairaWithdrawalFee.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bank Details Section
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BANK ACCOUNT DETAILS',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FormField<String>(
                            initialValue: _selectedBankCode,
                            validator: (val) {
                              if (_selectedBankCode == null) return 'Bank selection required';
                              return null;
                            },
                            builder: (fieldState) {
                              final selectedBank = _banks.firstWhere(
                                (b) => b['code']?.toString() == _selectedBankCode,
                                orElse: () => null,
                              );
                              final String? bankName = selectedBank?['name']?.toString();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await _openBankSelector();
                                      fieldState.didChange(_selectedBankCode);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Select Destination Bank',
                                        labelStyle: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surfaceContainerHighest,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: fieldState.hasError ? BorderSide(color: AppTheme.danger(context), width: 1.5) : BorderSide.none,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (bankName != null) ...[
                                            Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor.withOpacity(0.14),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                bankName.substring(0, 1).toUpperCase(),
                                                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w900, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Text(
                                              bankName ?? 'Tap to choose a bank',
                                              style: TextStyle(
                                                color: bankName != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(PhosphorIcons.caretDownBold, color: theme.colorScheme.onSurfaceVariant, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (fieldState.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, left: 12),
                                      child: Text(
                                        fieldState.errorText!,
                                        style: TextStyle(color: AppTheme.danger(context), fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _accountNumberController,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              labelText: '10-Digit NUBAN Account Number',
                              counterText: '',
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: _onAccountNumberChanged,
                            validator: (val) {
                              if (val == null || val.trim().length != 10) {
                                return 'Enter 10 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          if (_isResolvingAccount) ...[
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Resolving account details...',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_resolvedAccountName != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.success(context).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.success(context).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(PhosphorIcons.checkCircleFill, color: AppTheme.success(context), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _resolvedAccountName!,
                                      style: TextStyle(
                                        color: AppTheme.success(context),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_accountResolutionError != null) ...[
                            Text(
                              _accountResolutionError!,
                              style: TextStyle(
                                color: AppTheme.danger(context),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _handleCashOutClick,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(PhosphorIcons.bankFill, size: 20),
                        label: Text(
                          _isSubmitting ? 'PROCESSING CASH OUT...' : 'AUTHORIZE & CASH OUT',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
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
}