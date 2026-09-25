import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/pos_hardware_service.dart';

class PosAnalyticsReportScreen extends StatefulWidget {
  const PosAnalyticsReportScreen({super.key});

  @override
  State<PosAnalyticsReportScreen> createState() => _PosAnalyticsReportScreenState();
}

class _PosAnalyticsReportScreenState extends State<PosAnalyticsReportScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = true;
  String _timeframe = 'today'; 
  DateTimeRange? _customDateRange;

  double _totalSales = 0.0;
  int _ordersCount = 0;
  double _avgOrderValue = 0.0;
  double _totalTaxCollected = 0.0;
  double _totalPurchases = 0.0;
  double _grossProfit = 0.0;

  Map<String, double> _hourlySales = {};
  Map<String, double> _paymentModeSplit = {};
  List<Map<String, dynamic>> _topSellingItems = [];
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      if (_timeframe == 'today') {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (_timeframe == 'weekly') {
        start = now.subtract(const Duration(days: 7));
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (_timeframe == 'monthly') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (_customDateRange != null) {
        start = _customDateRange!.start;
        end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
      } else {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      }

      final ordersRes = await _client
          .from('shop_orders')
          .select()
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final List<dynamic> orders = ordersRes as List? ?? [];

      double sales = 0.0;
      final Map<String, int> itemQtyMap = {};
      final Map<String, double> itemRevenueMap = {};
      final Map<String, double> hourlyMap = {};
      final Map<String, double> paymentModeMap = {'cash': 0.0, 'upi': 0.0, 'wallet': 0.0, 'khata': 0.0, 'card': 0.0};

      double exactTaxCollected = 0.0;
      for (var o in orders) {
        final double price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        sales += price;

        final mode = (o['payment_mode']?.toString() ?? 'cash').toLowerCase();
        paymentModeMap[mode] = (paymentModeMap[mode] ?? 0.0) + price;

        final rawItems = o['items'];
        if (rawItems is List) {
          for (var it in rawItems) {
            final name = it['name']?.toString() ?? 'Item';
            final int qty = (it['quantity'] ?? it['qty'] as num?)?.toInt() ?? 1;
            final double itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
            final double itTaxRate = (it['tax_rate'] as num?)?.toDouble() ?? 0.0;
            itemQtyMap[name] = (itemQtyMap[name] ?? 0) + qty;
            itemRevenueMap[name] = (itemRevenueMap[name] ?? 0.0) + (qty * itPrice);
            if (itTaxRate > 0) {
              exactTaxCollected += (qty * itPrice) * (itTaxRate / 100.0);
            }
          }
        }

        final createdAtStr = o['created_at']?.toString();
        if (createdAtStr != null) {
          final dt = DateTime.tryParse(createdAtStr);
          if (dt != null) {
            final hourKey = "${dt.hour.toString().padLeft(2, '0')}:00";
            hourlyMap[hourKey] = (hourlyMap[hourKey] ?? 0.0) + price;
          }
        }
      }

      double purchases = 0.0;
      try {
        final procRes = await _client
            .from('procurements')
            .select('cost')
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String());
        for (var p in (procRes as List? ?? [])) {
          purchases += (p['cost'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {}

      final sortedItems = itemQtyMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topItems = sortedItems.take(10).map((e) => {
        'name': e.key,
        'quantity': e.value,
        'revenue': itemRevenueMap[e.key] ?? 0.0,
      }).toList();

      final taxAmt = exactTaxCollected;

      if (mounted) {
        setState(() {
          _totalSales = sales;
          _ordersCount = orders.length;
          _avgOrderValue = orders.isNotEmpty ? (sales / orders.length) : 0.0;
          _totalTaxCollected = taxAmt;
          _totalPurchases = purchases;
          _grossProfit = sales - purchases;
          _hourlySales = hourlyMap;
          _paymentModeSplit = paymentModeMap;
          _topSellingItems = topItems;
          _recentOrders = List<Map<String, dynamic>>.from(orders.take(50));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportReportPdf() async {
    final doc = pw.Document();
    final hardware = PosHardwareService();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(hardware.storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text("POS Sales & Purchase Financial Report", style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Timeframe: ${_timeframe.toUpperCase()}", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Text(DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfMetric("Total Sales", "₹ ${_totalSales.toStringAsFixed(2)}"),
              _pdfMetric("Orders Count", "$_ordersCount"),
              _pdfMetric("Avg Order Value", "₹ ${_avgOrderValue.toStringAsFixed(2)}"),
              _pdfMetric("Est. Tax (GST)", "₹ ${_totalTaxCollected.toStringAsFixed(2)}"),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Text("Top Selling Products", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Divider(thickness: 1),
          pw.TableHelper.fromTextArray(
            headers: ['Product Name', 'Quantity Sold', 'Total Revenue'],
            data: _topSellingItems.map((it) => [
              it['name'],
              it['quantity'].toString(),
              "₹ ${(it['revenue'] as double).toStringAsFixed(2)}"
            ]).toList(),
          ),
        ],
      ),
    );

    // Guaranteed execution flow returning bytes properly to layout/print/save handler
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'POS_Report_${_timeframe}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _pdfMetric(String title, String val) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(val, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln("Metric,Value");
    buffer.writeln("Timeframe,$_timeframe");
    buffer.writeln("Total Sales,$_totalSales");
    buffer.writeln("Total Orders,$_ordersCount");
    buffer.writeln("Average Order Value,$_avgOrderValue");
    buffer.writeln("Total Purchases,$_totalPurchases");
    buffer.writeln("Est. Tax (GST),$_totalTaxCollected");
    buffer.writeln("Gross Profit,$_grossProfit");
    buffer.writeln("");
    buffer.writeln("Top Products");
    buffer.writeln("Item Name,Quantity,Revenue");
    for (var it in _topSellingItems) {
      buffer.writeln('"${it['name']}",${it['quantity']},${it['revenue']}');
    }

    await Share.share(
      buffer.toString(),
      subject: 'POS_Sales_Report.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            AppBar(
              title: Text('POS Reports & Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: textColor, letterSpacing: 1.5)),
              backgroundColor: isDark ? const Color(0xFF121418) : Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              actions: [
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.greenAccent),
                  tooltip: 'Print Thermal Z-Report',
                  onPressed: () async {
                    final success = await PosHardwareService().printZReport(
                      timeframe: _timeframe,
                      totalSales: _totalSales,
                      orderCount: _ordersCount,
                      avgOrderValue: _avgOrderValue,
                      taxCollected: _totalTaxCollected,
                      totalPurchases: _totalPurchases,
                      grossProfit: _grossProfit,
                      topProducts: _topSellingItems,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Day-End Z-Report sent to printer' : 'Z-Report print canceled or failed'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.amber),
                  tooltip: 'Export PDF Report',
                  onPressed: _exportReportPdf,
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
                  tooltip: 'Share CSV Data',
                  onPressed: _exportCsv,
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: textColor),
                  tooltip: 'Refresh',
                  onPressed: _fetchReportData,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: textColor.withOpacity(0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.insights, size: 18), text: 'Overview'),
                  Tab(icon: Icon(Icons.shopping_bag_outlined, size: 18), text: 'Products'),
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Tickets'),
                ],
              ),
            ),
            _buildTimeframeSelector(isDark, textColor),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isDark, textColor),
                        _buildTopProductsTab(isDark, textColor),
                        _buildRecentTicketsTab(isDark, textColor),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector(bool isDark, Color textColor) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: textColor.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text('Interval: ', style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _timeChip('Today', 'today', isDark, textColor),
                  const SizedBox(width: 8),
                  _timeChip('Weekly (7d)', 'weekly', isDark, textColor),
                  const SizedBox(width: 8),
                  _timeChip('Monthly', 'monthly', isDark, textColor),
                  const SizedBox(width: 8),
                  ActionChip(
                    backgroundColor: _timeframe == 'custom' ? Colors.amber : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                    label: Text(
                      _customDateRange != null
                          ? "${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}"
                          : "Custom Range",
                      style: TextStyle(
                        fontSize: 12,
                        color: _timeframe == 'custom' ? Colors.black : textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _timeframe = 'custom';
                          _customDateRange = picked;
                        });
                        _fetchReportData();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String value, bool isDark, Color textColor) {
    final selected = _timeframe == value;
    return ChoiceChip(
      selected: selected,
      selectedColor: Colors.amber,
      backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _timeframe = value;
            _customDateRange = null;
          });
          _fetchReportData();
        }
      },
    );
  }

  Widget _buildOverviewTab(bool isDark, Color textColor) {
    final containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.3,
                children: [
                  _metricTile('Total Sales Revenue', '₹ ${_totalSales.toStringAsFixed(2)}', Icons.point_of_sale, Colors.greenAccent, containerBg, textColor),
                  _metricTile('Total Tickets / Orders', '$_ordersCount', Icons.receipt, Colors.lightBlueAccent, containerBg, textColor),
                  _metricTile('Avg Order Value (AOV)', '₹ ${_avgOrderValue.toStringAsFixed(2)}', Icons.pie_chart, Colors.purpleAccent, containerBg, textColor),
                  _metricTile('Estimated GST / Tax', '₹ ${_totalTaxCollected.toStringAsFixed(2)}', Icons.account_balance, Colors.amber, containerBg, textColor),
                  _metricTile('Procurement / Purchases', '₹ ${_totalPurchases.toStringAsFixed(2)}', Icons.shopping_basket, Colors.orangeAccent, containerBg, textColor),
                  _metricTile('Est. Gross Margin', '₹ ${_grossProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.tealAccent, containerBg, textColor),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales Velocity by Hour', style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_timeframe.toUpperCase()} TREND', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: _hourlySales.isEmpty
                ? Center(child: Text('No hourly transactions recorded yet in this timeframe', style: TextStyle(color: textColor.withOpacity(0.5))))
                : BarChart(
                    BarChartData(
                      barGroups: _hourlySales.entries.map((e) {
                        final hourInt = int.tryParse(e.key.split(':').first) ?? 0;
                        return BarChartGroupData(
                          x: hourInt,
                          barRods: [
                            BarChartRodData(
                              toY: e.value,
                              gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final h = val.toInt();
                              if (h % 3 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('${h.toString().padLeft(2, '0')}:00', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 9)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text('Tender / Payment Mode Distribution', style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                _paymentBreakdownRow('Cash Tender', _paymentModeSplit['cash'] ?? 0.0, _totalSales, Colors.greenAccent, textColor),
                const SizedBox(height: 10),
                _paymentBreakdownRow('UPI QR Scanner', _paymentModeSplit['upi'] ?? 0.0, _totalSales, Colors.lightBlueAccent, textColor),
                const SizedBox(height: 10),
                _paymentBreakdownRow('Student Wallet Balance', _paymentModeSplit['wallet'] ?? 0.0, _totalSales, Colors.tealAccent, textColor),
                const SizedBox(height: 10),
                _paymentBreakdownRow('Student Khata Ledger', _paymentModeSplit['khata'] ?? 0.0, _totalSales, Colors.amber, textColor),
                const SizedBox(height: 10),
                _paymentBreakdownRow('Card / EDC Terminal', _paymentModeSplit['card'] ?? 0.0, _totalSales, Colors.purpleAccent, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBreakdownRow(String label, double amount, double total, Color color, Color textColor) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            Text("₹ ${amount.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(1)}%)", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _metricTile(String title, String value, IconData icon, Color color, Color containerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11), maxLines: 1),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsTab(bool isDark, Color textColor) {
    if (_topSellingItems.isEmpty) {
      return Center(child: Text('No item sales logged in this period', style: TextStyle(color: textColor.withOpacity(0.5))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _topSellingItems.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
      itemBuilder: (context, index) {
        final item = _topSellingItems[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.amber.withOpacity(0.2),
            child: Text('#${index + 1}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
          title: Text(item['name'], style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          subtitle: Text("Quantity Sold: ${item['quantity']}", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
          trailing: Text("₹ ${(item['revenue'] as double).toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        );
      },
    );
  }

  Widget _buildRecentTicketsTab(bool isDark, Color textColor) {
    if (_recentOrders.isEmpty) {
      return Center(child: Text('No orders found', style: TextStyle(color: textColor.withOpacity(0.5))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recentOrders.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
      itemBuilder: (context, index) {
        final o = _recentOrders[index];
        final id = o['id']?.toString().substring(0, 8) ?? 'Order';
        final total = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
        final items = o['items'] is List ? (o['items'] as List).length : 0;

        final invoiceNum = o['invoice_number']?.toString().isNotEmpty == true
            ? o['invoice_number'].toString()
            : "INV-#$id";
        final mode = (o['payment_mode']?.toString() ?? 'cash').toUpperCase();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long, color: Colors.amber, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(invoiceNum, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(mode, style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          subtitle: Text(
            "${date != null ? DateFormat('dd MMM, hh:mm a').format(date) : ''} • $items items",
            style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("₹ ${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.greenAccent, size: 20),
                tooltip: 'Print Thermal Ticket',
                onPressed: () => _printSingleTicket(o),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.lightBlueAccent, size: 20),
                tooltip: 'Share / Save Receipt PDF',
                onPressed: () => _saveTicketPdf(o),
              ),
            ],
          ),
        );
      },
    );
  }

  PosReceiptData _buildReceiptDataFromOrder(Map<String, dynamic> o) {
    final hardware = PosHardwareService();
    final itemsList = <PosReceiptItem>[];
    if (o['items'] is List) {
      for (var it in (o['items'] as List)) {
        itemsList.add(PosReceiptItem(
          name: it['name']?.toString() ?? 'Product',
          quantity: (it['quantity'] ?? it['qty'] as num?)?.toInt() ?? 1,
          unitPrice: (it['price'] as num?)?.toDouble() ?? 0.0,
          totalPrice: ((it['price'] as num?)?.toDouble() ?? 0.0) * ((it['quantity'] ?? it['qty'] as num?)?.toInt() ?? 1),
          hsn: it['hsn_code']?.toString(),
          taxPercent: (it['tax_rate'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }

    final total = (o['total_price'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (o['subtotal'] as num?)?.toDouble() ?? total;
    final discount = (o['discount'] as num?)?.toDouble() ?? 0.0;
    final cgst = (o['cgst'] as num?)?.toDouble() ?? 0.0;
    final sgst = (o['sgst'] as num?)?.toDouble() ?? 0.0;
    final id = o['id']?.toString().substring(0, 8) ?? 'Order';
    final invNum = o['invoice_number']?.toString().isNotEmpty == true ? o['invoice_number'].toString() : "INV-#$id";
    final dt = DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now();

    return PosReceiptData(
      storeName: hardware.storeName,
      storeAddress: hardware.storeAddress,
      storeGstin: hardware.storeGstin,
      storePhone: hardware.storePhone,
      invoiceNumber: invNum,
      dateTime: dt,
      cashierName: "POS Terminal",
      customerName: o['user_id'] != null ? "Customer Account" : "Walk-in Customer",
      items: itemsList,
      subtotal: subtotal,
      discount: discount,
      cgst: cgst,
      sgst: sgst,
      total: total,
      paymentMode: o['payment_mode']?.toString() ?? 'cash',
      tenderedAmount: (o['tendered_amount'] as num?)?.toDouble(),
      changeAmount: (o['change_amount'] as num?)?.toDouble(),
      templateStyle: hardware.templateStyle,
      footerNote: hardware.footerNote,
    );
  }

  Future<void> _printSingleTicket(Map<String, dynamic> o) async {
    final receipt = _buildReceiptDataFromOrder(o);
    final ok = await PosHardwareService().printThermalReceipt(receipt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Ticket sent to printer / spooler' : 'Print failed or cancelled'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveTicketPdf(Map<String, dynamic> o) async {
    final receipt = _buildReceiptDataFromOrder(o);
    await PosHardwareService().shareReceiptPdf(receipt);
  }
}