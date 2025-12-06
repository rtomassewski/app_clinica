// lib/recibo_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; 
import 'financeiro_service.dart'; 

class ReciboService {
  
  // Função principal que chama a impressão
  static Future<void> imprimirRecibo({
    required TransacaoFinanceira transacao,
    required bool isTermica, // true = Cupom, false = A4
  }) async {
    final doc = pw.Document();

    // Define o formato da página
    // 80mm é o padrão de impressora térmica
    final pageFormat = isTermica ? PdfPageFormat.roll80 : PdfPageFormat.a4;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: isTermica 
            ? const pw.EdgeInsets.all(5) // Margem pequena na térmica
            : const pw.EdgeInsets.all(40), // Margem normal no A4
        build: (pw.Context context) {
          return isTermica 
              ? _buildLayoutTermico(transacao) 
              : _buildLayoutA4(transacao);
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Recibo-${transacao.id}',
    );
  }

  // --- LAYOUT PARA IMPRESSORA TÉRMICA (CUPOM) ---
  static pw.Widget _buildLayoutTermico(TransacaoFinanceira transacao) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final formatDate = DateFormat('dd/MM/yyyy HH:mm');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('THOMAS MED SOFT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.Text('Clinica de Recuperação', style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(), // <--- CORREÇÃO: Removido o style que dava erro
        pw.Text('COMPROVANTE DE PAGAMENTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 10),
        
        // Dados
        _linhaTermica("Data:", formatDate.format(transacao.dataVencimento)),
        _linhaTermica("Valor:", formatCurrency.format(transacao.valor)),
        _linhaTermica("Tipo:", transacao.tipo),
        
        pw.SizedBox(height: 5),
        pw.Divider(), // <--- CORREÇÃO: Linha sólida simples
        
        pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("Descricao:")),
        pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text(transacao.descricao, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        
        pw.SizedBox(height: 5),
        if (transacao.pacienteNome != null) ...[
           pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("Paciente:")),
           pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text(transacao.pacienteNome!)),
        ],

        pw.SizedBox(height: 20),
        pw.Text('Documento sem valor fiscal', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Impresso em: ${formatDate.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 10),
        pw.Text('.', style: const pw.TextStyle(fontSize: 1)), // Ponto final para garantir margem no corte
      ],
    );
  }

  static pw.Widget _linhaTermica(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    );
  }

  // --- LAYOUT PARA IMPRESSORA A4 (RECIBO FORMAL) ---
  static pw.Widget _buildLayoutA4(TransacaoFinanceira transacao) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final formatDate = DateFormat('dd/MM/yyyy');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('THOMAS MED SOFT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text('RECIBO Nº ${transacao.id}', style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey)),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VALOR', style: pw.TextStyle(fontSize: 14)),
                  pw.Text(formatCurrency.format(transacao.valor), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              pw.RichText(
                text: pw.TextSpan(
                  text: 'Recebemos de ',
                  style: const pw.TextStyle(fontSize: 14),
                  children: [
                    pw.TextSpan(text: transacao.pacienteNome ?? "Consumidor Final", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' a quantia referente a '),
                    pw.TextSpan(text: transacao.descricao, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              pw.Text('Data do Pagamento: ${formatDate.format(transacao.dataPagamento ?? DateTime.now())}'),
              pw.Text('Forma de Pagamento: ${transacao.tipo}'), 
            ],
          ),
        ),

        pw.SizedBox(height: 50),
        
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 200, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 5),
                pw.Text('Assinatura do Responsável'),
              ],
            ),
          ],
        ),
        
        pw.Spacer(),
        pw.Center(child: pw.Text("Sistema ThomasMedSoft - Gestão Inteligente", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
      ],
    );
  }
}