// lib/agenda_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Import necessário para Colors
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// --- NOVO ENUM: Status de Atendimento ---
enum StatusAtendimento {
  AGUARDANDO,
  ATENDIDO,
  CANCELADO,
  DESISTENCIA,
  REAGENDADO,
  NAO_COMPARECEU,
}

// --- EXTENSÃO: Facilita a exibição do Status na UI ---
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

// --- CLASSE AGENDAMENTO (com novo campo 'status') ---
class Agendamento {
  final int id;
  final DateTime dataHora;
  final int pacienteId;
  final int userId;
  final String? observacao;
  final String pacienteNome;
  final String? nomePrestador;
  final StatusAtendimento status; // <--- NOVO CAMPO

  Agendamento.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        dataHora = DateTime.parse(json['data_hora']),
        pacienteId = json['pacienteId'],
        userId = json['userId'],
        observacao = json['observacao'],
        pacienteNome = json['paciente']['nomeCompleto'],
        nomePrestador = json['user']?['nome_completo'],
        // Mapeia a string do JSON para o Enum
        status = StatusAtendimento.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
            orElse: () => StatusAtendimento.AGUARDANDO 
        );
}

// --- CLASSE AGENDA SERVICE ---
class AgendaService {
  final AuthService _authService;
 final String apiUrl = baseUrl;

  AgendaService(this._authService);

  // ... (getAgendamentos e addAgendamento aqui) ...

  Future<List<Agendamento>> getAgendamentos({DateTime? date}) async {
    // ... (MÉTODO EXISTENTE)
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    String query = '';
    if (date != null) {
      // Formato para buscar agendamentos em um dia específico
      query = '?date=${date.toIso8601String().split('T')[0]}';
    }

    final url = Uri.parse('$baseUrl/agendamentos$query');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Agendamento.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar agendamentos');
    }
  }

  Future<Agendamento> addAgendamento({
    required String dataHora,
    required int pacienteId,
    required int prestadorId,
    String? observacao,
  }) async {
    // ... (MÉTODO EXISTENTE)
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
        'data_hora': dataHora,
        'pacienteId': pacienteId,
        'userId': prestadorId,
        if (observacao != null) 'observacao': observacao,
      }),
    );

    if (response.statusCode == 201) {
      return Agendamento.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao adicionar agendamento: ${errorBody['message'] ?? response.statusCode}');
    }
  }

  // --- NOVO MÉTODO DE ATUALIZAÇÃO ---
  Future<void> updateAgendamento({
    required int agendamentoId,
    String? novaDataHora,
    StatusAtendimento? novoStatus,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final Map<String, dynamic> body = {};

    if (novaDataHora != null) {
      body['data_hora'] = novaDataHora; // Envia ISO String
    }

    if (novoStatus != null) {
      // Converte o enum Flutter para a string esperada pelo NestJS/Prisma (e.g., 'ATENDIDO')
      body['status'] = novoStatus.toString().split('.').last; 
    }
    
    if (body.isEmpty) return; // Não faz chamada se não há o que atualizar

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