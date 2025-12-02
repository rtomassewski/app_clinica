// lib/impressoes_service.dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart'; // Certifique-se que o baseUrl vem daqui

class ImpressoesService {
  final AuthService _authService;

  ImpressoesService(this._authService);

  // --- 1. PRONTUÁRIO (Agora com o nome correto: gerarProntuarioPdf) ---
  Future<Uint8List> gerarProntuarioPdf(int pacienteId) async {
    final token = await _authService.getToken();
    
    // Rota que definimos no Backend: /impressoes/paciente/:id/prontuario
    final url = Uri.parse('$baseUrl/impressoes/paciente/$pacienteId/prontuario');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes; // O PDF em si
    } else {
      throw Exception('Erro ao gerar prontuário: ${response.statusCode}');
    }
  }

  // --- 2. RELATÓRIO FINANCEIRO ---
  Future<Uint8List> gerarRelatorioFinanceiro({required DateTime inicio, required DateTime fim}) async {
    final token = await _authService.getToken();
    
    final inicioStr = inicio.toIso8601String();
    final fimStr = fim.toIso8601String();

    // Rota que definimos no Backend: /impressoes/financeiro
    final url = Uri.parse('$baseUrl/impressoes/financeiro?inicio=$inicioStr&fim=$fimStr');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Erro ao gerar relatório financeiro: ${response.statusCode}');
    }
  }
}