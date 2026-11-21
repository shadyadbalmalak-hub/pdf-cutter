import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() => runApp(const PdfCutterApp());

class PdfCutterApp extends StatelessWidget {
  const PdfCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'قصّاص الـ PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F766E),
        useMaterial3: true,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  Uint8List? _bytes;
  String _fileName = '';
  int _total = 0;
  bool _busy = false;
  String _msg = '';
  bool _isError = false;

  void _say(String text, {bool error = false}) {
    setState(() {
      _msg = text;
      _isError = error;
    });
  }

  // اختيار الملف
  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();

      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _total = count;
      });
      _say('');
    } catch (e) {
      _say('مقدرتش أفتح الملف ده. جرّب ملف تاني.', error: true);
    }
  }

  // قصّ الصفحات وحفظ الملف
  Future<void> _cutAndSave() async {
    if (_bytes == null) {
      _say('اختار الملف الأول', error: true);
      return;
    }

    var from = int.tryParse(_fromCtrl.text.trim());
    var to = int.tryParse(_toCtrl.text.trim());
    if (from == null || to == null) {
      _say('اكتب رقم أول صفحة وآخر صفحة', error: true);
      return;
    }
    if (from > to) {
      final t = from;
      from = to;
      to = t;
    }
    if (from < 1 || to > _total) {
      _say('الأرقام لازم تكون بين 1 و $_total', error: true);
      return;
    }

    setState(() => _busy = true);
    _say('بقصّ الصفحات...');

    try {
      final doc = PdfDocument(inputBytes: _bytes!);

      // نمسح أي صفحة برّه النطاق (من الآخر للأول)
      for (var i = doc.pages.count - 1; i >= 0; i--) {
        final pageNumber = i + 1;
        if (pageNumber < from || pageNumber > to) {
          doc.pages.removeAt(i);
        }
      }

      final out = Uint8List.fromList(await doc.save());
      doc.dispose();

      final baseName = _fileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      await FileSaver.instance.saveFile(
        name: '${baseName}_$from-$to',
        bytes: out,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      _say('تمام! الملف جاهز (${to - from + 1} صفحة) ✅');
    } catch (e) {
      _say('حصلت مشكلة وأنا بقصّ الملف.', error: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('✂️ قصّاص الـ PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'اختار الملف، اكتب من صفحة كام لحد صفحة كام، ودوس قصّ.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.picture_as_pdf),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _bytes == null ? 'اختار ملف PDF' : _fileName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'الملف فيه $_total صفحة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'من صفحة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _toCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'لحد صفحة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_busy || _bytes == null) ? null : _cutAndSave,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('قصّ وحمّل', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: _isError ? scheme.error : null),
            ),
          ],
        ),
      ),
    );
  }
}
