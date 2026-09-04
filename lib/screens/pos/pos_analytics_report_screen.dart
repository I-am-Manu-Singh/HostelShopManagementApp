import 'package:flutter/material.dart';
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
  String _timeframe = 'today'; // 'today', 'weekly', 'monthly', 'custom'
  DateTimeRange? _customDateRange;

  // Key Metrics
  double _totalSales = 0.0;
  int _ordersCount = 0;
  double _avgOrderValue = 0.0;
  double _totalTaxCollected = 0.0;
  double _totalPurchases = 0.0;
  double _grossProfit = 0.0;

  // Breakdown
  Map<String, double> _hourlySales = {};
  List<Map<String, dynamic>> _topSellingItems = [];
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      if (_timeframe == 'today') {
        start = DateTime(now.year, now.month, now.day);
      } else if (_timeframe == 'weekly') {
        start = now.subtract(const Duration(days: 7));
      } else if (_timeframe == 'monthly') {
        start = DateTime(now.year, now.month, 1);
      } else if (_customDateRange != null) {
        start = _customDateRange!.start;
        end = _customDateRange!.end.add(const Duration(days: 1));
      } else {
        start = DateTime(now.year, now.month, now.day);
      }

      // 1. Fetch Orders in range
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

      for (var o in orders) {
        final double price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        sales += price;

        final rawItems = o['items'];
        if (rawItems is List) {
          for (var it in rawItems) {
            final name = it['name']?.toString() ?? 'Item';
            final int qty = (it['quantity'] as num?)?.toInt() ?? 1;
            final double itPrice = (it['price'] as num?)?.toDouble() ?? 0.0;
            itemQtyMap[name] = (itemQtyMap[name] ?? 0) + qty;
            itemRevenueMap[name] = (itemRevenueMap[name] ?? 0.0) + (qty * itPrice);
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

      // 2. Fetch Procurements / Purchases in range
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

      // Top Selling Items list
      final sortedItems = itemQtyMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topItems = sortedItems.take(10).map((e) => {
        'name': e.key,
        'quantity': e.value,
        'revenue': itemRevenueMap[e.key] ?? 0.0,
      }).toList();

      // Taxes (estimated 5% or 12% blended GST)
      final taxAmt = sales * 0.05;

      setState(() {
        _totalSales = sales;
        _ordersCount = orders.length;
        _avgOrderValue = orders.isNotEmpty ? (sales / orders.length) : 0.0;
        _totalTaxCollected = taxAmt;
        _totalPurchases = purchases;
        _grossProfit = sales - purchases;
        _hourlySales = hourlyMap;
        _topSellingItems = topItems;
        _recentOrders = List<Map<String, dynamic>>.from(orders.take(30));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Analytics error: $e");
      setState(() => _isLoading = false);
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
              _pdfMetric("Total Sales", "Rs ${_totalSales.toStringAsFixed(2)}"),
              _pdfMetric("Orders Count", "$_ordersCount"),
              _pdfMetric("Avg Order Value", "Rs ${_avgOrderValue.toStringAsFixed(2)}"),
              _pdfMetric("Est. Tax (GST)", "Rs ${_totalTaxCollected.toStringAsFixed(2)}"),
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
              "Rs ${(it['revenue'] as double).toStringAsFixed(2)}"
            ]).toList(),
          ),
        ],
      ),
    );

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('POS Reports & Financial Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.amberAccent),
            tooltip: 'Export PDF Report',
            onPressed: _exportReportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
            tooltip: 'Share CSV Data',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _fetchReportData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(icon: Icon(Icons.insights), text: 'Overview & Velocity'),
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Top Products & Sales'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Recent Tickets'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Timeframe Filter Bar
          _buildTimeframeSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildTopProductsTab(),
                      _buildRecentTicketsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Interval: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Wrap(
            spacing: 8,
            children: [
              _timeChip('Today', 'today'),
              _timeChip('Weekly (7d)', 'weekly'),
              _timeChip('Monthly', 'monthly'),
              ActionChip(
                backgroundColor: _timeframe == 'custom' ? Colors.amberAccent : const Color(0xFF334155),
                label: Text(
                  _customDateRange != null
                      ? "${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}"
                      : "Custom Range",
                  style: TextStyle(
                    fontSize: 12,
                    color: _timeframe == 'custom' ? Colors.black : Colors.white,
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
        ],
      ),
    );
  }

  Widget _timeChip(String label, String value) {
    final selected = _timeframe == value;
    return ChoiceChip(
      selected: selected,
      selectedColor: Colors.amberAccent,
      backgroundColor: const Color(0xFF334155),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              _metricTile('Total Sales Revenue', 'Rs ${_totalSales.toStringAsFixed(2)}', Icons.point_of_sale, Colors.greenAccent),
              _metricTile('Total Tickets / Orders', '$_ordersCount', Icons.receipt, Colors.lightBlueAccent),
              _metricTile('Avg Order Value (AOV)', 'Rs ${_avgOrderValue.toStringAsFixed(2)}', Icons.pie_chart, Colors.purpleAccent),
              _metricTile('Estimated GST / Tax', 'Rs ${_totalTaxCollected.toStringAsFixed(2)}', Icons.account_balance, Colors.amberAccent),
              _metricTile('Procurement / Purchases', 'Rs ${_totalPurchases.toStringAsFixed(2)}', Icons.shopping_basket, Colors.orangeAccent),
              _metricTile('Est. Gross Margin', 'Rs ${_grossProfit.toStringAsFixed(2)}', Icons.trending_up, Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Hourly Sales Velocity (Today)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: _hourlySales.isEmpty
                ? const Center(child: Text('No hourly transactions recorded yet', style: TextStyle(color: Colors.white54)))
                : BarChart(
                    BarChartData(
                      barGroups: _hourlySales.entries.map((e) {
                        final hourInt = int.tryParse(e.key.split(':').first) ?? 0;
                        return BarChartGroupData(
                          x: hourInt,
                          barRods: [
                            BarChartRodData(
                              toY: e.value,
                              color: Colors.amberAccent,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsTab() {
    if (_topSellingItems.isEmpty) {
      return const Center(child: Text('No item sales logged in this period', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _topSellingItems.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final item = _topSellingItems[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
            child: Text('#${index + 1}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
          title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text("Quantity Sold: ${item['quantity']}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
          trailing: Text("Rs ${(item['revenue'] as double).toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        );
      },
    );
  }

  Widget _buildRecentTicketsTab() {
    if (_recentOrders.isEmpty) {
      return const Center(child: Text('No orders found', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recentOrders.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final o = _recentOrders[index];
        final id = o['id']?.toString().substring(0, 8) ?? 'Order';
        final total = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        final date = DateTime.tryParse(o['created_at']?.toString() ?? '');
        final items = o['items'] is List ? (o['items'] as List).length : 0;

        return ListTile(
          leading: const Icon(Icons.receipt, color: Colors.amberAccent),
          title: Text("Invoice #$id", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text("${date != null ? DateFormat('dd MMM, hh:mm a').format(date) : ''} • $items items", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Text("Rs ${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        );
      },
    );
  }
}
