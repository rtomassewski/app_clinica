// lib/financeiro_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart'; // Precisamos do modelo Paciente
import 'gestao_service.dart'; // Precisamos do modelo Papel (para o 'addCategoria')

// --- MODELOS DE DADOS ---
enum TipoTransacao {
  RECEITA,
  DESPESA
}

class CategoriaFinanceira {
  final int id;
  final String nome;
  final String tipo; // 'RECEITA' ou 'DESPESA'

  CategoriaFinanceira({required this.id, required this.nome, required this.tipo});

  factory CategoriaFinanceira.fromJson(Map<String, dynamic> json) {
    return CategoriaFinanceira(
      id: json['id'],
      nome: json['nome'],
      tipo: json['tipo'],
    );
  }
}

class TransacaoFinanceira {
  final int id;
  final String descricao;
  final double valor;
  final String tipo; // 'RECEITA' ou 'DESPESA'
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final String categoriaNome;
  final String? pacienteNome;

  TransacaoFinanceira({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.dataVencimento,
    this.dataPagamento,
    required this.categoriaNome,
    this.pacienteNome,
  });

  factory TransacaoFinanceira.fromJson(Map<String, dynamic> json) {
    return TransacaoFinanceira(
      id: json['id'],
      descricao: json['descricao'],
      valor: json['valor'].toDouble(),
      tipo: json['tipo'],
      dataVencimento: DateTime.parse(json['data_vencimento']),
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'])
          : null,
      categoriaNome: json['categoria']['nome'],
      pacienteNome: json['paciente']?['nome_completo'],
    );
  }
}

// --- O SERVIÇO ---

class FinanceiroService {
  final AuthService _authService;
  FinanceiroService(this._authService);

  // GET /categorias-financeiras
  Future<List<CategoriaFinanceira>> getCategorias() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/categorias-financeiras');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => CategoriaFinanceira.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar categorias.');
    }
  }

  // GET /transacoes-financeiras
  Future<List<TransacaoFinanceira>> getTransacoes() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/transacoes-financeiras');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => TransacaoFinanceira.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar transações.');
    }
  }

  // POST /transacoes-financeiras
  Future<void> addTransacao({
    required String descricao,
    required double valor,
    required String tipo, // 'RECEITA' ou 'DESPESA'
    required DateTime dataVencimento,
    required int categoriaId,
    int? pacienteId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/transacoes-financeiras');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'descricao': descricao,
        'valor': valor,
        'tipo': tipo,
        'data_vencimento': dataVencimento.toIso8601String(),
        'categoriaId': categoriaId,
        'pacienteId': pacienteId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao salvar transação.');
    }
  }

  // PATCH /transacoes-financeiras/:id (para marcar como PAGO)
  Future<void> marcarComoPaga(int transacaoId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/transacoes-financeiras/$transacaoId');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        // Define a data de pagamento como 'agora'
        'data_pagamento': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao marcar como paga.');
    }
  } // <-- Fim do 'marcarComoPaga'

  // POST /categorias-financeiras
  // (Este método estava DENTRO do 'marcarComoPaga' no seu código)
  Future<void> addCategoria({
    required String nome,
    required TipoTransacao tipo,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/categorias-financeiras');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome': nome,
        'tipo': tipo.name, // Envia a string "RECEITA" ou "DESPESA"
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar categoria. Status: ${response.statusCode}');
    }
  } // <-- Fim do 'addCategoria'

} // <-- Fim da classe 'FinanceiroService'