// lib/impressoes_service.dart
import 'dart:typed_data'; // Para lidar com os bytes do PDF
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class ImpressoesService {
  final AuthService _authService;
  ImpressoesService(this._authService);

  // GET /impressoes/paciente/:id/prontuario
  Future<Uint8List> gerarProntuarioPdf(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/impressoes/paciente/$pacienteId/prontuario');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // 1. Sucesso: Retorna o corpo da resposta como bytes
        return response.bodyBytes;
      } else {
        // 2. Falha (403, 404, 500)
        throw Exception('Falha ao gerar o PDF. Status: ${response.statusCode}');
      }
    } catch (e) {
      // 3. Erro de rede
      throw Exception('Erro de conexão: $e');
    }
  }
}