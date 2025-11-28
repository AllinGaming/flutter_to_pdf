import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const PdfCanvasApp());
}

class PdfCanvasApp extends StatelessWidget {
  const PdfCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Canvas',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F766E),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      ),
      home: const CanvasHome(),
    );
  }
}

enum CanvasElementKind { text, box, image }

class CanvasElement {
  CanvasElement({
    required this.id,
    required this.kind,
    required this.offset,
    required this.size,
    this.text,
    this.color = const Color(0xFFE0E7FF),
    this.textStyle,
    this.bytes,
    this.radius = 8,
  });

  final String id;
  final CanvasElementKind kind;
  Offset offset;
  Size size;
  String? text;
  Color color;
  TextStyle? textStyle;
  Uint8List? bytes;
  double radius;
}

class CanvasHome extends StatefulWidget {
  const CanvasHome({super.key});

  @override
  State<CanvasHome> createState() => _CanvasHomeState();
}

class _CanvasHomeState extends State<CanvasHome> {
  final _uuid = const Uuid();
  final List<CanvasElement> _elements = [];
  CanvasElement? _selected;
  final pdf.PdfPageFormat _pageFormat = pdf.PdfPageFormat.a4;
  late final Size _pageSize = Size(
    pdf.PdfPageFormat.a4.width,
    pdf.PdfPageFormat.a4.height,
  );
  double _scale = 0.9;
  bool _snapToGrid = true;
  bool _showGuides = true;
  double _gridSize = 18;
  double _snapGrid = 4;
  double _guideMargin = 24;
  static const double _canvasInset = 16;
  final List<Color> _swatches = const [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF0EA5E9),
    Color(0xFF111827),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _buildPalette();
    final canvas = _buildCanvas();
    final inspector = _buildInspector();
    final preview = _buildPreview();

    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            palette,
            Expanded(child: canvas),
            inspector,
            preview,
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('PDF Canvas', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(
            'Freeform A4 builder',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _snapToGrid ? 'Disable grid snap' : 'Enable grid snap',
          icon: Icon(_snapToGrid ? Icons.grid_on : Icons.grid_off),
          onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
        ),
        IconButton(
          tooltip: _showGuides ? 'Hide guides' : 'Show guides',
          icon: Icon(_showGuides ? Icons.layers_outlined : Icons.layers_clear),
          onPressed: () => setState(() => _showGuides = !_showGuides),
        ),
        IconButton(
          tooltip: 'Zoom out',
          icon: const Icon(Icons.zoom_out),
          onPressed: () => setState(() => _scale = max(0.5, _scale - 0.05)),
        ),
        IconButton(
          tooltip: 'Zoom in',
          icon: const Icon(Icons.zoom_in),
          onPressed: () => setState(() => _scale = min(1.2, _scale + 0.05)),
        ),
        IconButton(
          tooltip: 'Share PDF',
          icon: const Icon(Icons.ios_share_outlined),
          onPressed: _exportPdf,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _statusChip(
                icon: Icons.picture_as_pdf_outlined,
                label: 'A4 portrait',
              ),
              _statusChip(
                icon: Icons.grid_on,
                label: _snapToGrid ? 'Grid snapping' : 'Freehand',
              ),
              _statusChip(
                icon: Icons.tune,
                label: 'Scale ${(_scale * 100).round()}%',
              ),
              _statusChip(
                icon: Icons.layers,
                label: '${_elements.length} layers',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.teal.shade700),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPalette() {
    return SizedBox(
      width: 200,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Elements',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _addText,
                  icon: const Icon(Icons.title),
                  label: const Text('Text'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _addBox,
                  icon: const Icon(Icons.crop_square),
                  label: const Text('Rectangle'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _addImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Image'),
                ),
                const Divider(height: 24),
                const Text(
                  'Templates',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _templateChip('Header + Body', _addHeaderAndBody),
                    _templateChip('Two column', _addTwoColumnLayout),
                    _templateChip('Cover hero', _addCoverHero),
                    _templateChip('Callout', _addCallout),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Guides & snap',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _labeledSlider(
                  label: 'Guide spacing',
                  value: _gridSize,
                  min: 8,
                  max: 32,
                  onChanged: (v) => setState(() => _gridSize = v),
                  suffix: '${_gridSize.round()} px',
                ),
                _labeledSlider(
                  label: 'Guide margin',
                  value: _guideMargin,
                  min: 12,
                  max: 48,
                  onChanged: (v) => setState(() => _guideMargin = v),
                  suffix: '${_guideMargin.round()} px',
                ),
                _labeledSlider(
                  label: 'Snap step',
                  value: _snapGrid,
                  min: 2,
                  max: 12,
                  onChanged: (v) => setState(() => _snapGrid = v),
                  suffix: '${_snapGrid.toStringAsFixed(1)} px',
                ),
                const Divider(height: 24),
                ElevatedButton.icon(
                  onPressed: _clear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade800,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: const Color(0xFFE0F2F1),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    );
  }

  Widget _buildCanvas() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: _canvasViewSize.width,
          height: _canvasViewSize.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_canvasInset),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _showGuides
                          ? CustomPaint(
                              painter: _GuidePainter(
                                grid: _gridSize * _scale,
                                color: Colors.grey.shade200,
                                margin: _guideMargin * _scale,
                              ),
                            )
                          : null,
                    ),
                  ),
                  ..._elements.map(_buildElementWidget),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElementWidget(CanvasElement e) {
    final isSelected = _selected?.id == e.id;
    return Positioned(
      left: e.offset.dx * _scale,
      top: e.offset.dy * _scale,
      child: GestureDetector(
        onTap: () => setState(() => _selected = e),
        onPanUpdate: (details) {
          final snapped = _snap(details.delta / _scale, e.offset);
          final bounded = _clampOffset(snapped, e.size);
          setState(() {
            e.offset = bounded;
          });
        },
        child: Stack(
          children: [
            Container(
              width: e.size.width * _scale,
              height: e.size.height * _scale,
              decoration: BoxDecoration(
                color: e.kind == CanvasElementKind.box
                    ? e.color
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.teal : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                  style: isSelected ? BorderStyle.solid : BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(e.radius),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: _renderElementContent(e),
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final newSize = Size(
                      max(24, e.size.width + details.delta.dx / _scale),
                      max(24, e.size.height + details.delta.dy / _scale),
                    );
                    e.size = _clampSize(newSize, e.offset);
                  });
                },
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderElementContent(CanvasElement e) {
    switch (e.kind) {
      case CanvasElementKind.text:
        return Text(
          e.text ?? 'Text',
          style:
              e.textStyle ?? const TextStyle(fontSize: 16, color: Colors.black),
        );
      case CanvasElementKind.box:
        return const SizedBox.shrink();
      case CanvasElementKind.image:
        if (e.bytes == null) {
          return const Center(child: Text('Image'));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(e.radius),
          child: Image.memory(e.bytes!, fit: BoxFit.cover),
        );
    }
  }

  Widget _buildInspector() {
    final e = _selected;
    return SizedBox(
      width: 260,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: e == null
              ? const Text('Select an element to edit properties')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Element ${e.kind.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (e.kind == CanvasElementKind.text)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: TextEditingController(
                                text: e.text ?? '',
                              ),
                              onChanged: (v) => setState(() => e.text = v),
                              decoration: const InputDecoration(
                                labelText: 'Text',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Font size'),
                                      Slider(
                                        value: e.textStyle?.fontSize ?? 16,
                                        min: 10,
                                        max: 48,
                                        label:
                                            '${(e.textStyle?.fontSize ?? 16).round()}',
                                        onChanged: (v) => setState(
                                          () => _updateTextStyle(e, size: v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'Bold',
                                  onPressed: () => setState(
                                    () => _updateTextStyle(
                                      e,
                                      weight:
                                          _isBold(
                                            e.textStyle?.fontWeight ??
                                                FontWeight.normal,
                                          )
                                          ? FontWeight.w400
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.format_bold,
                                    color:
                                        _isBold(
                                          e.textStyle?.fontWeight ??
                                              FontWeight.normal,
                                        )
                                        ? Colors.teal
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _swatches
                                  .map(
                                    (c) => GestureDetector(
                                      onTap: () => setState(
                                        () => _updateTextStyle(e, color: c),
                                      ),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.black12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Opacity'),
                                Expanded(
                                  child: Slider(
                                    value: e.color.a,
                                    min: 0.2,
                                    max: 1,
                                    onChanged: (v) => setState(
                                      () => e.color = e.color.withValues(
                                        alpha: v,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (e.kind == CanvasElementKind.box)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Color'),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      e.color = _randomColor();
                                    });
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: e.color,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _swatches
                                  .map(
                                    (c) => GestureDetector(
                                      onTap: () => setState(() => e.color = c),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.black12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            _labeledSlider(
                              label: 'Corner radius',
                              value: e.radius,
                              min: 0,
                              max: 32,
                              onChanged: (v) =>
                                  setState(() => e.radius = v.roundToDouble()),
                              suffix: '${e.radius.round()} px',
                            ),
                          ],
                        ),
                      if (e.kind == CanvasElementKind.image)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result != null &&
                                result.files.single.bytes != null) {
                              setState(() {
                                e.bytes = result.files.single.bytes;
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Replace image'),
                        ),
                      if (e.kind == CanvasElementKind.image)
                        _labeledSlider(
                          label: 'Corner radius',
                          value: e.radius,
                          min: 0,
                          max: 32,
                          onChanged: (v) =>
                              setState(() => e.radius = v.roundToDouble()),
                          suffix: '${e.radius.round()} px',
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('W'),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: _numberField(
                              e.size.width,
                              (v) => setState(
                                () => e.size = Size(v, e.size.height),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('H'),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: _numberField(
                              e.size.height,
                              (v) => setState(
                                () => e.size = Size(e.size.width, v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('X'),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: _numberField(
                              e.offset.dx,
                              (v) => setState(
                                () => e.offset = Offset(v, e.offset.dy),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Y'),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: _numberField(
                              e.offset.dy,
                              (v) => setState(
                                () => e.offset = Offset(e.offset.dx, v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _metricRow(e),
                      const SizedBox(height: 12),
                      const Text('Layout'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _actionChip(
                            icon: Icons.copy_all,
                            label: 'Duplicate',
                            onTap: () => _duplicateSelected(e),
                          ),
                          _actionChip(
                            icon: Icons.flip_to_front,
                            label: 'Bring forward',
                            onTap: () => _bringForward(e),
                          ),
                          _actionChip(
                            icon: Icons.flip_to_back,
                            label: 'Send backward',
                            onTap: () => _sendBackward(e),
                          ),
                          _actionChip(
                            icon: Icons.align_horizontal_center,
                            label: 'Center horizontally',
                            onTap: () => _alignHorizontally(e),
                          ),
                          _actionChip(
                            icon: Icons.align_vertical_center,
                            label: 'Center vertically',
                            onTap: () => _alignVertically(e),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _elements.removeWhere((el) => el.id == e.id);
                            _selected = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete element'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(
              suffix,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  void _updateTextStyle(
    CanvasElement e, {
    double? size,
    FontWeight? weight,
    Color? color,
  }) {
    final base = e.textStyle ?? const TextStyle(fontSize: 16);
    e.textStyle = base.copyWith(
      fontSize: size ?? base.fontSize,
      fontWeight: weight ?? base.fontWeight,
      color: color ?? base.color,
    );
  }

  bool _isBold(FontWeight weight) {
    return weight.value >= FontWeight.w600.value;
  }

  Widget _numberField(double value, ValueChanged<double> onChanged) {
    final controller = TextEditingController(text: value.toStringAsFixed(0));
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onSubmitted: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final data = await _buildPdfDocument(pdf.PdfPageFormat.a4);
    await Printing.sharePdf(bytes: data, filename: 'canvas.pdf');
  }

  Widget _buildPreview() {
    return SizedBox(
      width: 340,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'PDF Preview',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PdfPreview(
                canDebug: kDebugMode,
                allowPrinting: true,
                allowSharing: true,
                initialPageFormat: pdf.PdfPageFormat.a4,
                pdfFileName: 'canvas.pdf',
                build: (format) => _buildPdfDocument(format),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdfDocument(pdf.PdfPageFormat format) async {
    final doc = pw.Document(title: 'PDF Canvas');
    final elements = List<CanvasElement>.from(_elements);
    pw.Widget renderElement(CanvasElement e) {
      switch (e.kind) {
        case CanvasElementKind.text:
          return pw.Container(
            width: e.size.width,
            height: e.size.height,
            child: pw.Text(
              e.text ?? '',
              style: pw.TextStyle(
                fontSize: e.textStyle?.fontSize ?? 14,
                fontWeight: _toPdfWeight(e.textStyle?.fontWeight),
                color: pdfColorFromFlutter(e.textStyle?.color ?? Colors.black),
              ),
            ),
          );
        case CanvasElementKind.box:
          final argb = e.color.toARGB32();
          return pw.Container(
            width: e.size.width,
            height: e.size.height,
            decoration: pw.BoxDecoration(
              color: pdf.PdfColor.fromInt(argb),
              borderRadius: pw.BorderRadius.circular(e.radius),
            ),
          );
        case CanvasElementKind.image:
          if (e.bytes == null) return pw.Container();
          final img = pw.MemoryImage(e.bytes!);
          return pw.Container(
            width: e.size.width,
            height: e.size.height,
            child: pw.ClipRRect(
              horizontalRadius: e.radius,
              verticalRadius: e.radius,
              child: pw.Image(img, fit: pw.BoxFit.cover),
            ),
          );
      }
    }

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: _pageFormat,
          margin: pw.EdgeInsets.all(_canvasInset),
        ),
        build: (context) {
          return pw.Stack(
            children: [
              for (final e in elements)
                pw.Positioned(
                  left: e.offset.dx,
                  top: e.offset.dy,
                  child: renderElement(e),
                ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  pw.FontWeight? _toPdfWeight(FontWeight? weight) {
    if (weight == null) return null;
    switch (weight) {
      case FontWeight.w100:
      case FontWeight.w200:
      case FontWeight.w300:
        return pw.FontWeight.normal;
      case FontWeight.w400:
      case FontWeight.w500:
        return pw.FontWeight.normal;
      case FontWeight.w600:
      case FontWeight.w700:
      case FontWeight.w800:
      case FontWeight.w900:
        return pw.FontWeight.bold;
      default:
        return pw.FontWeight.normal;
    }
  }

  Offset _snap(Offset delta, Offset origin) {
    return snapOffset(delta, origin, grid: _snapGrid, enabled: _snapToGrid);
  }

  Size get _contentSize => contentArea(_pageSize, insetPerSide: _canvasInset);

  Size get _canvasViewSize =>
      Size(_pageSize.width * _scale, _pageSize.height * _scale);

  Offset _clampOffset(Offset next, Size size) {
    final maxX = _contentSize.width - size.width;
    final maxY = _contentSize.height - size.height;
    return Offset(next.dx.clamp(0, maxX), next.dy.clamp(0, maxY));
  }

  Size _clampSize(Size size, Offset origin) {
    final maxW = _contentSize.width - origin.dx;
    final maxH = _contentSize.height - origin.dy;
    return Size(size.width.clamp(24, maxW), size.height.clamp(24, maxH));
  }

  void _duplicateSelected(CanvasElement e) {
    setState(() {
      final clone = duplicateElement(e, _uuid.v4());
      _elements.add(clone);
      _selected = clone;
    });
  }

  void _bringForward(CanvasElement e) {
    final next = bringForwardById(_elements, e.id);
    if (next == _elements) return;
    setState(
      () => _elements
        ..clear()
        ..addAll(next),
    );
  }

  void _sendBackward(CanvasElement e) {
    final next = sendBackwardById(_elements, e.id);
    if (next == _elements) return;
    setState(
      () => _elements
        ..clear()
        ..addAll(next),
    );
  }

  Widget _metricRow(CanvasElement e) {
    final posMm = Offset(ptsToMm(e.offset.dx), ptsToMm(e.offset.dy));
    final sizeMm = Size(ptsToMm(e.size.width), ptsToMm(e.size.height));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position (mm)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        Text(
          'X ${posMm.dx.toStringAsFixed(1)}, Y ${posMm.dy.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        const Text(
          'Size (mm)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        Text(
          'W ${sizeMm.width.toStringAsFixed(1)}, H ${sizeMm.height.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  void _alignHorizontally(CanvasElement e) {
    final centerX = computeCenteredOffset(
      _contentSize.width,
      e.size.width,
      insetPerSide: 0,
    );
    setState(() => e.offset = Offset(centerX, e.offset.dy));
  }

  void _alignVertically(CanvasElement e) {
    final centerY = computeCenteredOffset(
      _contentSize.height,
      e.size.height,
      insetPerSide: 0,
    );
    setState(() => e.offset = Offset(e.offset.dx, centerY));
  }

  void _addHeaderAndBody() {
    setState(() {
      final newElements = buildHeaderBodyTemplate(_uuid.v4);
      _elements.addAll(newElements);
      _selected = newElements.lastWhere(
        (el) => el.kind == CanvasElementKind.text,
        orElse: () => newElements.last,
      );
    });
  }

  void _addTwoColumnLayout() {
    setState(() {
      final newElements = buildTwoColumnTemplate(_uuid.v4);
      _elements.addAll(newElements);
      _selected = newElements.lastWhere(
        (el) => el.kind == CanvasElementKind.text,
        orElse: () => newElements.last,
      );
    });
  }

  void _addCoverHero() {
    setState(() {
      final newElements = buildCoverHeroTemplate(_uuid.v4);
      _elements.addAll(newElements);
      _selected = newElements.firstWhere(
        (el) => el.kind == CanvasElementKind.text,
        orElse: () => newElements.first,
      );
    });
  }

  void _addCallout() {
    setState(() {
      final newElements = buildCalloutTemplate(_uuid.v4);
      _elements.addAll(newElements);
      _selected = newElements.firstWhere(
        (el) => el.kind == CanvasElementKind.text,
        orElse: () => newElements.first,
      );
    });
  }

  void _addText() {
    setState(() {
      _elements.add(
        CanvasElement(
          id: _uuid.v4(),
          kind: CanvasElementKind.text,
          offset: const Offset(40, 40),
          size: const Size(160, 40),
          text: 'Text',
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
    });
  }

  void _addBox() {
    setState(() {
      _elements.add(
        CanvasElement(
          id: _uuid.v4(),
          kind: CanvasElementKind.box,
          offset: const Offset(80, 80),
          size: const Size(120, 80),
          color: _randomColor(),
        ),
      );
    });
  }

  void _addImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _elements.add(
          CanvasElement(
            id: _uuid.v4(),
            kind: CanvasElementKind.image,
            offset: const Offset(60, 120),
            size: const Size(180, 120),
            bytes: result.files.single.bytes,
          ),
        );
      });
    }
  }

  void _clear() {
    setState(() {
      _elements.clear();
      _selected = null;
    });
  }

  Color _randomColor() {
    final rnd = Random();
    return Color.fromARGB(
      255,
      120 + rnd.nextInt(120),
      120 + rnd.nextInt(120),
      120 + rnd.nextInt(120),
    );
  }
}

pdf.PdfColor pdfColorFromFlutter(Color color) {
  return pdf.PdfColor.fromInt(color.toARGB32());
}

@visibleForTesting
double computeCenteredOffset(
  double containerSize,
  double childSize, {
  double insetPerSide = 0,
}) {
  final usable = max(0.0, containerSize - insetPerSide * 2);
  final start = insetPerSide + (usable - childSize) / 2;
  final minStart = insetPerSide;
  final maxStart = max(insetPerSide, containerSize - childSize - insetPerSide);
  return start.clamp(minStart, maxStart);
}

@visibleForTesting
Offset snapOffset(
  Offset delta,
  Offset origin, {
  bool enabled = true,
  double grid = 4,
}) {
  final next = origin + delta;
  if (!enabled) return next;
  double snapVal(double v) => (v / grid).round() * grid;
  return Offset(snapVal(next.dx), snapVal(next.dy));
}

@visibleForTesting
Size contentArea(Size pageSize, {required double insetPerSide}) {
  return Size(
    max(0, pageSize.width - insetPerSide * 2),
    max(0, pageSize.height - insetPerSide * 2),
  );
}

@visibleForTesting
double ptsToMm(double pts) => pts * 25.4 / 72.0;

@visibleForTesting
CanvasElement duplicateElement(CanvasElement source, String newId) {
  return CanvasElement(
    id: newId,
    kind: source.kind,
    offset: source.offset + const Offset(16, 16),
    size: source.size,
    text: source.text,
    color: source.color,
    textStyle: source.textStyle,
    bytes: source.bytes != null ? Uint8List.fromList(source.bytes!) : null,
    radius: source.radius,
  );
}

@visibleForTesting
List<CanvasElement> bringForwardById(List<CanvasElement> elements, String id) {
  final list = List<CanvasElement>.from(elements);
  final idx = list.indexWhere((el) => el.id == id);
  if (idx == -1 || idx == list.length - 1) return list;
  final item = list.removeAt(idx);
  list.insert(idx + 1, item);
  return list;
}

@visibleForTesting
List<CanvasElement> sendBackwardById(List<CanvasElement> elements, String id) {
  final list = List<CanvasElement>.from(elements);
  final idx = list.indexWhere((el) => el.id == id);
  if (idx <= 0) return list;
  final item = list.removeAt(idx);
  list.insert(idx - 1, item);
  return list;
}

List<CanvasElement> buildHeaderBodyTemplate(String Function() id) {
  final header = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(48, 40),
    size: const Size(420, 48),
    text: 'Executive summary headline',
    textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
  );
  final bodyBox = CanvasElement(
    id: id(),
    kind: CanvasElementKind.box,
    offset: const Offset(40, 110),
    size: const Size(500, 520),
    color: const Color(0xFFE0F2F1),
  );
  return [bodyBox, header];
}

List<CanvasElement> buildTwoColumnTemplate(String Function() id) {
  final left = CanvasElement(
    id: id(),
    kind: CanvasElementKind.box,
    offset: const Offset(40, 120),
    size: const Size(220, 540),
    color: const Color(0xFFE0E7FF),
  );
  final right = CanvasElement(
    id: id(),
    kind: CanvasElementKind.box,
    offset: const Offset(280, 120),
    size: const Size(220, 540),
    color: const Color(0xFFF3F4F6),
  );
  final heading = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(40, 50),
    size: const Size(420, 40),
    text: 'Two-column brief',
    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
  );
  return [left, right, heading];
}

List<CanvasElement> buildCoverHeroTemplate(String Function() id) {
  final heroBox = CanvasElement(
    id: id(),
    kind: CanvasElementKind.box,
    offset: const Offset(30, 120),
    size: const Size(520, 260),
    color: const Color(0xFF0EA5E9),
  );
  final title = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(48, 60),
    size: const Size(440, 44),
    text: 'Cover hero layout',
    textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
  );
  final subtitle = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(48, 400),
    size: const Size(420, 36),
    text: 'Add sub-copy and imagery on top',
    textStyle: const TextStyle(fontSize: 16, color: Colors.black54),
  );
  return [heroBox, title, subtitle];
}

List<CanvasElement> buildCalloutTemplate(String Function() id) {
  final box = CanvasElement(
    id: id(),
    kind: CanvasElementKind.box,
    offset: const Offset(60, 160),
    size: const Size(420, 160),
    color: const Color(0xFFFFF7ED),
    radius: 12,
  );
  final title = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(80, 180),
    size: const Size(360, 32),
    text: 'Callout / KPI highlight',
    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  );
  final body = CanvasElement(
    id: id(),
    kind: CanvasElementKind.text,
    offset: const Offset(80, 220),
    size: const Size(360, 60),
    text: 'Use this block to emphasize numbers or warnings.',
    textStyle: const TextStyle(fontSize: 14, color: Colors.black87),
  );
  return [box, title, body];
}

// Draws subtle grid and margin guides on the canvas to help precise layouting.
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.grid,
    required this.color,
    required this.margin,
  });

  final double grid;
  final Color color;
  final double margin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = margin; x < size.width - margin; x += grid) {
      canvas.drawLine(
        Offset(x, margin),
        Offset(x, size.height - margin),
        paint,
      );
    }
    for (double y = margin; y < size.height - margin; y += grid) {
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
    }

    final marginPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.color != color ||
        oldDelegate.margin != margin;
  }
}
