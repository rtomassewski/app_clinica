// lib/agenda_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart'; // Para modelos Paciente/Profissional

// --- ENUM CORRIGIDO (Igual ao Banco de Dados) ---
enum StatusAtendimento {
  AGENDADO,  // Era AGUARDANDO
  REALIZADO, // Era ATENDIDO
  CANCELADO, // Igual
  FALTOU     // Era NAO_COMPARECEU
}

// --- EXTENSÃO ATUALIZADA ---
extension StatusExtension on StatusAtendimento {
  String get nomeFormatado {
    switch (this) {
      case StatusAtendimento.AGENDADO:
        return 'Aguardando'; // Visualmente mostramos "Aguardando"
      case StatusAtendimento.REALIZADO:
        return 'Atendido';   // Visualmente mostramos "Atendido"
      case StatusAtendimento.CANCELADO:
        return 'Cancelado';
      case StatusAtendimento.FALTOU:
        return 'Faltou';
    }
  }

  Color get cor {
    switch (this) {
      case StatusAtendimento.AGENDADO:
        return Colors.blue; // Azul para agendado
      case StatusAtendimento.REALIZADO:
        return Colors.green; // Verde para realizado
      case StatusAtendimento.CANCELADO:
        return Colors.red; // Vermelho para cancelado
      case StatusAtendimento.FALTOU:
        return Colors.purple; // Roxo para falta
    }
  }
}
// --- FIM ENUM ---

// --- CLASSE AGENDAMENTO ---
class Agendamento {
  final int id;
  final DateTime dataHora;
  final int pacienteId;
  final int userId;
  final String? observacao;
  final String? pacienteNome;
  final String? nomePrestador;
  final StatusAtendimento status; 

  Agendamento.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        dataHora = DateTime.parse(json['data_hora_inicio']),
        pacienteId = json['pacienteId'],
        userId = json['usuarioId'],
        observacao = json['observacao'],
        pacienteNome = json['paciente']?['nome_completo'] as String?,
        nomePrestador = json['usuario']?['nome_completo'] as String?,
        
        // Mapeia a string do JSON para o Enum (CORRIGIDO)
        status = StatusAtendimento.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
            orElse: () => StatusAtendimento.AGENDADO // Padrão seguro
        );
}


// --- CLASSE AGENDA SERVICE ---
class AgendaService {
  final AuthService _authService;
  
  // Use a constante do api_config.dart
  // final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 

  AgendaService(this._authService);

  // GET AGENDAMENTOS
  Future<List<Agendamento>> getAgendamentos({DateTime? date}) async {
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

  // ADICIONAR
  Future<Agendamento> addAgendamento({
    required int pacienteId,
    required int usuarioId,
    required String data_hora_inicio,
    String? observacao,
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
        // O status padrão (AGENDADO) é definido pelo banco, não precisamos enviar
      }),
    );

    if (response.statusCode == 201) {
      return Agendamento.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao adicionar: ${errorBody['message'] ?? response.statusCode}');
    }
  }

  // ATUALIZAR
  Future<void> updateAgendamento({
    required int agendamentoId,
    String? novaDataHora,
    StatusAtendimento? novoStatus,
    String? observacao,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final Map<String, dynamic> body = {};

    if (novaDataHora != null) {
      body['data_hora_inicio'] = novaDataHora;
    }

    if (novoStatus != null) {
      // Envia a string exata (ex: "REALIZADO") para o Back-End
      body['status'] = novoStatus.toString().split('.').last; 
    }
    
    if (observacao != null) {
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
      throw Exception('Falha ao atualizar: ${errorBody['message'] ?? response.statusCode}');
    }
  }
}