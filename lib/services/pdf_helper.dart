import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfHelper {
  PdfHelper._();

  static Future<File> generatePdf({
    required String fileName,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    
    await file.writeAsBytes(bytes);
    return file;
  }
}
