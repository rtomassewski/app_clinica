import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart'; // Certifique-se de ter sua URL base aqui

class Evolucao {
  final int id;
  final String descricao;
  final DateTime data;
  final String nomeProfissional;
  final String cargoProfissional;

  Evolucao({
    required this.id,
    required this.descricao,
    required this.data,
    required this.nomeProfissional,
    required this.cargoProfissional,
  });

  factory Evolucao.fromJson(Map<String, dynamic> json) {
    return Evolucao(
      id: json['id'],
      descricao: json['descricao'],
      data: DateTime.parse(json['data_evolucao']),
      nomeProfissional: json['usuario']['nome_completo'] ?? 'Desconhecido',
      cargoProfissional: json['usuario']['papel']?['nome'] ?? '',
    );
  }
}

class EvolucaoService {
  final AuthService _authService;
  // Ajuste a URL conforme seu ambiente (Render ou Local)
  final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 

  EvolucaoService(this._authService);

  // Criar Evolução e Finalizar Agendamento
  Future<void> criarEvolucao({
    required int pacienteId,
    required String descricao,
    required int agendamentoId, // Obrigatório para fechar a agenda
    String tipo = 'GERAL',
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/evolucoes');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pacienteId': pacienteId,
        'descricao': descricao,
        'agendamentoId': agendamentoId,
        'tipo': tipo,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Erro ao salvar evolução: ${response.body}');
    }
  }

  // Buscar Histórico do Paciente
  Future<List<Evolucao>> getHistorico(int pacienteId) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/evolucoes/paciente/$pacienteId');
    
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      List jsonList = jsonDecode(response.body);
      return jsonList.map((e) => Evolucao.fromJson(e)).toList();
    } else {
      return [];
    }
  }
}