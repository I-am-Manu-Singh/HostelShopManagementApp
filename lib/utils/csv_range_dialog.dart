import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum CsvRangeType { dateToDate, monthToMonth, finYearToFinYear }

class CsvRangeSelection {
  final DateTime startDate;
  final DateTime endDate;
  final CsvRangeType type;

  CsvRangeSelection({
    required this.startDate,
    required this.endDate,
    required this.type,
  });
}

Future<CsvRangeSelection?> showCsvRangeDialog({
  required BuildContext context,
  required String title,
  bool isImport = false,
}) async {
  return showDialog<CsvRangeSelection>(
    context: context,
    builder: (context) => _CsvRangeDialogWidget(title: title, isImport: isImport),
  );
}

class _CsvRangeDialogWidget extends StatefulWidget {
  final String title;
  final bool isImport;
  const _CsvRangeDialogWidget({required this.title, required this.isImport});

  @override
  State<_CsvRangeDialogWidget> createState() => _CsvRangeDialogWidgetState();
}

class _CsvRangeDialogWidgetState extends State<_CsvRangeDialogWidget> {
  CsvRangeType _selectedType = CsvRangeType.monthToMonth;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  // Fin Year selections
  String _selectedFinYear = 'FY 2025-26';
  final List<String> _finYears = ['FY 2023-24', 'FY 2024-25', 'FY 2025-26', 'FY 2026-27'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF16181A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        '${widget.isImport ? "IMPORT" : "EXPORT"} RANGE LIMITER\n${widget.title.toUpperCase()}',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: Colors.indigoAccent,
          letterSpacing: 1.5,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Segmented selection
            DropdownButtonFormField<CsvRangeType>(
              value: _selectedType,
              dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
              decoration: InputDecoration(
                labelText: 'FILTER MODE',
                labelStyle: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: [
                DropdownMenuItem(
                  value: CsvRangeType.dateToDate,
                  child: Text('Date to Date', style: GoogleFonts.outfit(fontSize: 13, color: textColor)),
                ),
                DropdownMenuItem(
                  value: CsvRangeType.monthToMonth,
                  child: Text('Month to Month', style: GoogleFonts.outfit(fontSize: 13, color: textColor)),
                ),
                DropdownMenuItem(
                  value: CsvRangeType.finYearToFinYear,
                  child: Text('Financial Year', style: GoogleFonts.outfit(fontSize: 13, color: textColor)),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            if (_selectedType == CsvRangeType.dateToDate) ...[
              _buildDatePicker(
                label: 'START DATE',
                value: _startDate,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _startDate = d);
                },
              ),
              const SizedBox(height: 12),
              _buildDatePicker(
                label: 'END DATE',
                value: _endDate,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _endDate = d);
                },
              ),
            ] else if (_selectedType == CsvRangeType.monthToMonth) ...[
              _buildDatePicker(
                label: 'START MONTH',
                value: _startDate,
                dateFormat: 'MMMM yyyy',
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (d != null) {
                    setState(() => _startDate = DateTime(d.year, d.month, 1));
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDatePicker(
                label: 'END MONTH',
                value: _endDate,
                dateFormat: 'MMMM yyyy',
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (d != null) {
                    setState(() => _endDate = DateTime(d.year, d.month + 1, 0));
                  }
                },
              ),
            ] else if (_selectedType == CsvRangeType.finYearToFinYear) ...[
              DropdownButtonFormField<String>(
                value: _selectedFinYear,
                dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
                decoration: InputDecoration(
                  labelText: 'SELECT FINANCIAL YEAR',
                  labelStyle: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _finYears
                    .map((fy) => DropdownMenuItem(
                          value: fy,
                          child: Text(fy, style: GoogleFonts.outfit(fontSize: 13, color: textColor)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedFinYear = val;
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ),
        ElevatedButton(
          onPressed: () {
            DateTime finalStart = _startDate;
            DateTime finalEnd = _endDate;

            if (_selectedType == CsvRangeType.finYearToFinYear) {
              // Parse Fin Year like FY 2025-26
              final parts = _selectedFinYear.split(' ');
              if (parts.length == 2) {
                final years = parts[1].split('-');
                final startYear = int.tryParse(years[0]) ?? 2025;
                finalEnd = DateTime(startYear + 1, 3, 31, 23, 59, 59);
                finalStart = DateTime(startYear, 4, 1);
              }
            }

            Navigator.pop(
              context,
              CsvRangeSelection(
                startDate: finalStart,
                endDate: finalEnd,
                type: _selectedType,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigoAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(widget.isImport ? 'IMPORT' : 'EXPORT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    String dateFormat = 'dd MMM yyyy',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                const SizedBox(height: 4),
                Text(DateFormat(dateFormat).format(value), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent, size: 20),
          ],
        ),
      ),
    );
  }
}
