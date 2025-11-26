// lib/agenda_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// --- ENUM (Mantemos igual ao Banco) ---
enum StatusAtendimento {
  AGENDADO,
  REALIZADO,
  CANCELADO,
  FALTOU
}

extension StatusExtension on StatusAtendimento {
  String get nomeFormatado {
    switch (this) {
      case StatusAtendimento.AGENDADO: return 'Aguardando';
      case StatusAtendimento.REALIZADO: return 'Atendido';
      case StatusAtendimento.CANCELADO: return 'Cancelado';
      case StatusAtendimento.FALTOU: return 'Faltou';
    }
  }

  Color get cor {
    switch (this) {
      case StatusAtendimento.AGENDADO: return Colors.blue;
      case StatusAtendimento.REALIZADO: return Colors.green;
      case StatusAtendimento.CANCELADO: return Colors.red;
      case StatusAtendimento.FALTOU: return Colors.purple;
    }
  }
}

// --- CLASSE AGENDAMENTO ATUALIZADA ---
class Agendamento {
  final int id;
  final DateTime dataHora;
  final int pacienteId;
  final int userId;
  final String? observacao;
  final String? pacienteNome;
  final String? nomePrestador;
  final StatusAtendimento status;
  
  // NOVOS CAMPOS
  final double valorTotal;
  final List<String> procedimentosNomes; // Apenas para exibir na lista

  Agendamento.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        dataHora = DateTime.parse(json['data_hora_inicio']),
        pacienteId = json['pacienteId'],
        userId = json['usuarioId'],
        observacao = json['observacao'],
        pacienteNome = json['paciente']?['nome_completo'] as String?,
        nomePrestador = json['usuario']?['nome_completo'] as String?,
        status = StatusAtendimento.values.firstWhere(
            (e) => e.toString().split('.').last == json['status'],
            orElse: () => StatusAtendimento.AGENDADO
        ),
        // Mapeia os novos campos
        valorTotal = (json['valor_total'] as num?)?.toDouble() ?? 0.0,
        procedimentosNomes = (json['procedimentos'] as List<dynamic>?)
            ?.map((p) => p['procedimento']['nome'] as String)
            .toList() ?? [];
}

class AgendaService {
  final AuthService _authService;
  // final String baseUrl = "http://10.0.2.2:3000"; // Use a URL correta (Local ou Render)
  final String baseUrl = "https://thomasmedsoft-api.onrender.com";

  AgendaService(this._authService);

  // LISTAR
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

  // ADICIONAR (ATUALIZADO PARA RECEBER PROCEDIMENTOS)
  Future<Agendamento> addAgendamento({
    required int pacienteId,
    required int usuarioId,
    required String data_hora_inicio,
    String? observacao,
    List<int>? procedimentoIds, // <-- NOVO PARÂMETRO
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
        'procedimentoIds': procedimentoIds ?? [], // Envia a lista
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

    if (novaDataHora != null) body['data_hora_inicio'] = novaDataHora;
    if (novoStatus != null) body['status'] = novoStatus.toString().split('.').last;
    if (observacao != null) body['observacao'] = observacao;

    if (body.isEmpty) return;

    final url = Uri.parse('$baseUrl/agendamentos/$agendamentoId');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao atualizar: ${errorBody['message']}');
    }
  }
}