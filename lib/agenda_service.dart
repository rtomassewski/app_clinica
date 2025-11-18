// lib/agenda_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Import necessário para Colors
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart'; // Para modelos Paciente/Profissional/Prescricao, etc.

// --- Enum e Extensões (assumindo que estão corretos) ---
// NOTA: Se você tiver StatusAtendimento definido aqui e no paciente_service.dart,
// o erro de colisão de nomes irá reaparecer! Mantenha a definição em apenas um local.
enum StatusAtendimento {
  AGUARDANDO,
  ATENDIDO,
  CANCELADO,
  DESISTENCIA,
  REAGENDADO,
  NAO_COMPARECEU,
}
extension StatusExtension on StatusAtendimento {
  String get nomeFormatado {
    switch (this) {
      case StatusAtendimento.AGUARDANDO:
        return 'Aguardando';
      case StatusAtendimento.ATENDIDO:
        return 'Atendido';
      case StatusAtendimento.CANCELADO:
        return 'Cancelado';
      case StatusAtendimento.DESISTENCIA:
        return 'Desistência';
      case StatusAtendimento.REAGENDADO:
        return 'Reagendado';
      case StatusAtendimento.NAO_COMPARECEU:
        return 'Não Compareceu';
    }
  }
  Color get cor {
    switch (this) {
      case StatusAtendimento.AGUARDANDO:
        return Colors.blue;
      case StatusAtendimento.ATENDIDO:
        return Colors.green;
      case StatusAtendimento.CANCELADO:
        return Colors.red;
      case StatusAtendimento.DESISTENCIA:
        return Colors.red.shade700;
      case StatusAtendimento.REAGENDADO:
        return Colors.orange;
      case StatusAtendimento.NAO_COMPARECEU:
        return Colors.purple;
    }
  }
}
// --- FIM ENUM/EXTENSÕES ---


// --- CLASSE AGENDAMENTO (assumindo que está correta e completa) ---
class Agendamento {
  final int id;
  final DateTime dataHora;
  final int pacienteId;
  final int userId;
  final String? observacao;
  
  // CORREÇÃO: Tornar estes campos nullable (String?) para evitar o crash
  final String? pacienteNome; 
  final String? nomePrestador; 
  
  final StatusAtendimento status; 

  Agendamento.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        dataHora = DateTime.parse(json['data_hora_inicio']),
        pacienteId = json['pacienteId'],
        userId = json['usuarioId'],
        observacao = json['observacao'],
        
        // CORREÇÃO: Mapeamento seguro (se for null, atribui null)
        pacienteNome = json['paciente']?['nome_completo'] as String?,
        nomePrestador = json['usuario']?['nome_completo'] as String?,
        
        status = StatusAtendimento.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
            orElse: () => StatusAtendimento.AGUARDANDO 
        );
}


// --- CLASSE AGENDA SERVICE (CORRIGIDO) ---
class AgendaService {
  final AuthService _authService;
  // NOTA: O 'baseUrl' deve ser importado da api_config.dart
  final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 

  AgendaService(this._authService);

  // GET AGENDAMENTOS
  Future<List<Agendamento>> getAgendamentos({DateTime? date}) async {
    // ... (código existente) ...
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    String query = '';
    if (date != null) {
      query = '?date=${date.toIso8601String().split('T')[0]}';
    }

    final url = Uri.parse('$baseUrl/agendamentos$query');

    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Agendamento.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar agendamentos.');
    }
  }

  // MÉTODO DE CRIAÇÃO (CORRIGIDO PARA ACEITAR O DTO DO BACK-END)
  Future<Agendamento> addAgendamento({
    required int pacienteId,
    required int usuarioId, // <-- CORREÇÃO: USAR nome correto do Back-End
    required String data_hora_inicio, // <-- CORREÇÃO: USAR nome correto do Back-End
    String? observacao, // <-- ADICIONADO: Para consistência com o Service/DTO
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/agendamentos');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data_hora_inicio': data_hora_inicio,
        'pacienteId': pacienteId,
        'usuarioId': usuarioId,
        'observacao': observacao,
      }),
    );

    if (response.statusCode == 201) {
      return Agendamento.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao adicionar agendamento: ${errorBody['message'] ?? response.statusCode}');
    }
  }

  // MÉTODO DE ATUALIZAÇÃO (CORRIGIDO PARA ACEITAR OBSERVAÇÃO)
  Future<void> updateAgendamento({
    required int agendamentoId,
    String? novaDataHora,
    StatusAtendimento? novoStatus,
    String? observacao, // <-- CORREÇÃO: ADICIONADO ESTE PARÂMETRO
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final Map<String, dynamic> body = {};

    if (novaDataHora != null) {
      body['data_hora_inicio'] = novaDataHora; // USAR data_hora_inicio
    }

    if (novoStatus != null) {
      body['status'] = novoStatus.toString().split('.').last; 
    }
    
    if (observacao != null) { // NOVO
      body['observacao'] = observacao;
    }

    if (body.isEmpty) return;

    final url = Uri.parse('$baseUrl/agendamentos/$agendamentoId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao atualizar agendamento: ${errorBody['message'] ?? response.statusCode}');
    }
  }
}