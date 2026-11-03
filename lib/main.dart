
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

const List<String> stockCategories = [
  'Electronics',
  'Stationery',
  'Hardware',
  'Grocery',
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stock Inventory Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StockInventoryHome(),
    );
  }
}

class StockInventoryHome extends StatefulWidget {
  const StockInventoryHome({super.key});

  @override
  State<StockInventoryHome> createState() =>
      _StockInventoryHomeState();
}

class _StockInventoryHomeState extends State<StockInventoryHome> {
  final _formKey = GlobalKey<FormState>();

  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _reorderController = TextEditingController();
  final _searchController = TextEditingController();

  String? _category;
  String _categoryFilter = 'All';
  bool _lowStockOnly = false;
  bool _sortAscending = true;
  bool _isSaving = false;

  final CollectionReference<Map<String, dynamic>> _stockCollection =
  FirebaseFirestore.instance.collection('stockItems');

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _reorderController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ensureFiveSampleItems();
  }

  // Adds sample records only when the collection contains fewer than five items.
  // Existing records are preserved; duplicate sample SKUs are not added.
  Future<void> _ensureFiveSampleItems() async {
    try {
      final existing = await _stockCollection.get();
      if (existing.docs.length >= 5) return;

      final existingSkus = existing.docs
          .map((doc) => (doc.data()['sku'] ?? '').toString())
          .toSet();

      final samples = <Map<String, dynamic>>[
        {
          'sku': 'STK-102',
          'itemName': 'Mouse',
          'category': 'Electronics',
          'quantity': 20,
          'unitPrice': 25.00,
          'reorderLevel': 5,
        },
        {
          'sku': 'STK-103',
          'itemName': 'Keyboard',
          'category': 'Electronics',
          'quantity': 15,
          'unitPrice': 45.00,
          'reorderLevel': 5,
        },
        {
          'sku': 'STK-104',
          'itemName': 'USB Cable',
          'category': 'Hardware',
          'quantity': 3,
          'unitPrice': 12.00,
          'reorderLevel': 5,
        },
      ];

      var count = existing.docs.length;
      for (final sample in samples) {
        if (count >= 5) break;
        final sku = sample['sku'] as String;
        if (existingSkus.contains(sku)) continue;
        await _stockCollection.add({
          ...sample,
          'createdAt': FieldValue.serverTimestamp(),
        });
        existingSkus.add(sku);
        count++;
      }
    } catch (e) {
      debugPrint('Could not add sample inventory items: $e');
    }
  }

  String _formatCreatedAt(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${date.year}-${two(date.month)}-${two(date.day)} '
          '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
    }
    return 'Pending';
  }

  String? _validateSku(String? value) {
    final sku = value?.trim() ?? '';

    if (!RegExp(r'^STK-\d{3}$').hasMatch(sku)) {
      return 'Enter a SKU such as STK-101';
    }

    return null;
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().length < 3) {
      return 'Item name must contain at least 3 characters';
    }

    return null;
  }

  String? _validateInteger(String? value, String field) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);

    if (text.isEmpty) {
      return '$field is required';
    }

    if (number == null || number < 0) {
      return '$field must be a whole number, 0 or above';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    final price = double.tryParse(text);

    if (text.isEmpty) {
      return 'Unit price is required';
    }

    if (price == null || !price.isFinite || price <= 0) {
      return 'Enter a price greater than RM 0';
    }

    return null;
  }

  Future<void> _saveItem() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_category == null || !stockCategories.contains(_category)) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final sku = _skuController.text.trim();
    final itemName = _nameController.text.trim();
    final quantity = int.parse(_quantityController.text.trim());
    final unitPrice = double.parse(_priceController.text.trim());
    final reorderLevel = int.parse(_reorderController.text.trim());

    setState(() => _isSaving = true);

    try {
      await _stockCollection.add({
        'sku': sku,
        'itemName': itemName,
        'category': _category!,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'reorderLevel': reorderLevel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _skuController.clear();
      _nameController.clear();
      _quantityController.clear();
      _priceController.clear();
      _reorderController.clear();

      setState(() {
        _category = null;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock item saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save item. Please try again. $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _categoryFilter = 'All';
      _lowStockOnly = false;
      _sortAscending = true;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterItems(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
      ) {
    final keyword = _searchController.text.trim().toLowerCase();

    final filtered = documents.where((document) {
      final data = document.data();

      final name = (data['itemName'] ?? '').toString().toLowerCase();
      final sku = (data['sku'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString();

      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final reorderLevel =
          (data['reorderLevel'] as num?)?.toInt() ?? 0;

      final matchesKeyword =
          keyword.isEmpty ||
              name.contains(keyword) ||
              sku.toLowerCase().contains(keyword);

      final matchesCategory =
          _categoryFilter == 'All' ||
              category == _categoryFilter;

      final matchesLowStock =
          !_lowStockOnly || quantity <= reorderLevel;

      return matchesKeyword &&
          matchesCategory &&
          matchesLowStock;
    }).toList();

    filtered.sort((a, b) {
      final quantityA =
          (a.data()['quantity'] as num?)?.toInt() ?? 0;
      final quantityB =
          (b.data()['quantity'] as num?)?.toInt() ?? 0;

      return _sortAscending
          ? quantityA.compareTo(quantityB)
          : quantityB.compareTo(quantityA);
    });

    return filtered;
  }

  Widget _buildStockCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    final sku = (data['sku'] ?? '').toString();
    final name = (data['itemName'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
    final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
    final reorderLevel =
        (data['reorderLevel'] as num?)?.toInt() ?? 0;
    final createdAt = _formatCreatedAt(data['createdAt']);

    final isLowStock = quantity <= reorderLevel;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
          isLowStock ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            Icons.inventory_2,
            color: isLowStock ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          '$name ($sku)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Category: $category\n'
                'Quantity: $quantity\n'
                'Unit Price: RM ${price.toStringAsFixed(2)}\n'
                'Reorder Level: $reorderLevel\n'
                'Created At: $createdAt\n'
                '${isLowStock ? 'LOW STOCK' : 'Stock available'}',
          ),
        ),
        isThreeLine: true,
        trailing: isLowStock
            ? const Icon(Icons.warning_amber, color: Colors.red)
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inventory Manager'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Stock Item',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      hintText: 'STK-101',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateSku,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: stockCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _category = value);
                    },
                    validator: (value) {
                      if (value == null ||
                          !stockCategories.contains(value)) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _validateInteger(value, 'Quantity'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _priceController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (RM)',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePrice,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _reorderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reorder Level',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _validateInteger(value, 'Reorder level'),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveItem,
                      icon: _isSaving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Item',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 36),

            const Text(
              'Stock Inventory',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by item name or SKU',
                hintText: 'Example: mouse or STK-102',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchController.clear());
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _categoryFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Category',
                border: OutlineInputBorder(),
              ),
              items: ['All', ...stockCategories].map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _categoryFilter = value ?? 'All');
              },
            ),
            const SizedBox(height: 8),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show low-stock items only'),
              subtitle: const Text(
                'Quantity less than or equal to reorder level',
              ),
              value: _lowStockOnly,
              onChanged: (value) {
                setState(() => _lowStockOnly = value ?? false);
              },
            ),

            DropdownButtonFormField<bool>(
              value: _sortAscending,
              decoration: const InputDecoration(
                labelText: 'Sort by Quantity',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: true,
                  child: Text('Ascending (lowest first)'),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text('Descending (highest first)'),
                ),
              ],
              onChanged: (value) {
                setState(() => _sortAscending = value ?? true);
              },
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear Filters'),
            ),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stockCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Unable to load inventory. Check your '
                          'Firebase connection and Firestore rules.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final documents = snapshot.data?.docs ?? [];

                if (documents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No stock items yet. Add your first item above.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final visibleItems = _filterItems(documents);

                if (visibleItems.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No matching stock items found. '
                          'Try changing your filters.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Showing ${visibleItems.length} item(s)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...visibleItems.map(_buildStockCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
