// lib/agenda_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart'; 

// --- 1. ENUMS ---

enum StatusAtendimento { AGENDADO, REALIZADO, CANCELADO, FALTOU }
enum StatusPagamento { PENDENTE, PAGO } // <--- NOVO
enum MetodoPagamento { DINHEIRO, PIX, CREDITO, DEBITO, BOLETO } // <--- NOVO

// --- EXTENSIONS (Cores e Textos) ---

extension StatusExtension on StatusAtendimento {
  String get nomeFormatado => toString().split('.').last;
  Color get cor {
    switch (this) {
      case StatusAtendimento.AGENDADO: return Colors.blue;
      case StatusAtendimento.REALIZADO: return Colors.green;
      case StatusAtendimento.CANCELADO: return Colors.red;
      case StatusAtendimento.FALTOU: return Colors.orange;
    }
  }
}

extension PagamentoExtension on StatusPagamento {
  String get nome => this == StatusPagamento.PAGO ? "Pago" : "Pendente";
  Color get cor => this == StatusPagamento.PAGO ? Colors.green[800]! : Colors.red[800]!;
}

// --- 2. MODELO AGENDAMENTO ---

class Agendamento {
  final int id;
  final DateTime dataHora;
  final StatusAtendimento status;
  final String? observacao;
  final int pacienteId;
  final String? pacienteNome;
  final int userId; 
  final String? profissionalNome;
  final List<String> procedimentosNomes;
  final double valorTotal;
  
  // Novos Campos Financeiros
  final StatusPagamento statusPagamento;
  final MetodoPagamento? metodoPagamento;

  Agendamento({
    required this.id,
    required this.dataHora,
    required this.status,
    this.observacao,
    required this.pacienteId,
    this.pacienteNome,
    required this.userId,
    this.profissionalNome,
    required this.procedimentosNomes,
    this.valorTotal = 0.0,
    this.statusPagamento = StatusPagamento.PENDENTE,
    this.metodoPagamento,
  });

  String? get nomePrestador => profissionalNome;

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    // Parse Data
    DateTime data = DateTime.now();
    if (json['data_hora_inicio'] != null) data = DateTime.parse(json['data_hora_inicio']);

    // Parse Status Atendimento
    StatusAtendimento statusEnum = StatusAtendimento.AGENDADO;
    if (json['status'] != null) {
      try {
        statusEnum = StatusAtendimento.values.firstWhere(
          (e) => e.toString().split('.').last == json['status'].toString().toUpperCase(),
          orElse: () => StatusAtendimento.AGENDADO,
        );
      } catch (_) {}
    }

    // Parse Status Pagamento (NOVO)
    StatusPagamento pagEnum = StatusPagamento.PENDENTE;
    if (json['status_pagamento'] == 'PAGO') pagEnum = StatusPagamento.PAGO;

    // Parse Metodo Pagamento (NOVO)
    MetodoPagamento? metodoEnum;
    if (json['metodo_pagamento'] != null) {
       try {
        metodoEnum = MetodoPagamento.values.firstWhere(
          (e) => e.toString().split('.').last == json['metodo_pagamento'].toString().toUpperCase()
        );
      } catch (_) {}
    }

    // Lista Procedimentos e Valor
    List<String> procs = [];
    if (json['procedimentos'] != null && json['procedimentos'] is List) {
      procs = (json['procedimentos'] as List).map((item) => item['procedimento']?['nome'].toString() ?? "Proc").toList();
    }
    double valor = double.tryParse(json['valor_total'].toString()) ?? 0.0;

    return Agendamento(
      id: json['id'],
      dataHora: data,
      status: statusEnum,
      observacao: json['observacao'],
      pacienteId: json['pacienteId'] ?? 0,
      pacienteNome: json['paciente']?['nome_completo'] ?? 'Paciente',
      userId: json['usuarioId'] ?? 0,
      profissionalNome: json['usuario']?['nome_completo'],
      procedimentosNomes: procs,
      valorTotal: valor,
      statusPagamento: pagEnum,
      metodoPagamento: metodoEnum,
    );
  }
}

// --- 3. SERVIÇO ---

class AgendaService {
  final AuthService _authService;
  final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 

  AgendaService(this._authService);

  Future<List<Agendamento>> getAgendamentos({DateTime? date}) async {
    final token = await _authService.getToken();
    String query = "";
    if (date != null) {
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      query = "?date=$dateStr";
    }
    final url = Uri.parse('$baseUrl/agendamentos$query');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      List jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Agendamento.fromJson(json)).toList();
    } else {
      if (response.statusCode == 403) return [];
      throw Exception('Erro agenda: ${response.statusCode}');
    }
  }

  Future<void> addAgendamento({
    required int pacienteId,
    required int usuarioId,
    required String data_hora_inicio,
    required List<int> procedimentoIds,
    String? observacao,
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/agendamentos');
    final body = {
      'pacienteId': pacienteId,
      'usuarioId': usuarioId,
      'data_hora_inicio': data_hora_inicio,
      'procedimentoIds': procedimentoIds, 
      'observacao': observacao ?? '',
    };
    final response = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (response.statusCode != 201) throw Exception('Erro criar: ${response.body}');
  }

  // UPDATE COMPLETO (Incluindo Financeiro)
  Future<void> updateAgendamento({
    required int agendamentoId,
    StatusAtendimento? novoStatus,
    String? novaDataHora,
    String? observacao,
    StatusPagamento? statusPagamento, // Vem como Enum do Front
    MetodoPagamento? metodoPagamento, // Vem como Enum do Front
    double? valorPago,
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/agendamentos/$agendamentoId');

    final Map<String, dynamic> body = {};

    if (novoStatus != null) body['status'] = novoStatus.toString().split('.').last;
    if (novaDataHora != null) body['data_hora_inicio'] = novaDataHora;
    if (observacao != null) body['observacao'] = observacao;
    
    // --- ADAPTAÇÃO PARA O SEU SCHEMA ---
    if (statusPagamento != null) {
      // Converte Enum 'PAGO'/'PENDENTE' para Boolean true/false
      body['pago'] = (statusPagamento == StatusPagamento.PAGO);
    }

    if (metodoPagamento != null) {
      // Mapeia os nomes do Front para os nomes do Banco
      // Ex: MetodoPagamento.PIX -> "PIX"
      body['forma_pagamento'] = metodoPagamento.toString().split('.').last;
    }

    if (valorPago != null) {
      body['valor_pago'] = valorPago;
    }
    // -----------------------------------

    final response = await http.patch(
      url, 
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
      body: jsonEncode(body)
    );
    
    if (response.statusCode != 200) throw Exception('Erro update: ${response.body}');
  }}