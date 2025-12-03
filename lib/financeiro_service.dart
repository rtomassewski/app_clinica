// lib/financeiro_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Necessário para ChangeNotifier
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart'; 
import 'gestao_service.dart'; 

// --- 1. NOVOS MODELOS (CAIXA) ---

class CaixaDiario {
  final int id;
  final double saldoInicial;
  final String status; // 'ABERTO' ou 'FECHADO'
  
  CaixaDiario({required this.id, required this.saldoInicial, required this.status});

  factory CaixaDiario.fromJson(Map<String, dynamic> json) {
    return CaixaDiario(
      id: json['id'], 
      saldoInicial: double.tryParse(json['saldo_inicial'].toString()) ?? 0.0, 
      status: json['status']
    );
  }
}

// --- MODELOS EXISTENTES ---

enum TipoTransacao { RECEITA, DESPESA }

class CategoriaFinanceira {
  final int id;
  final String nome;
  final String tipo; 

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
  final String tipo; 
  final DateTime dataVencimento;
  final DateTime? dataPagamento;
  final String categoriaNome;
  final String? pacienteNome;
  
  final int? usuarioBaixaId; 

  TransacaoFinanceira({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.dataVencimento,
    this.dataPagamento,
    required this.categoriaNome,
    this.pacienteNome,
    this.usuarioBaixaId, 
  });

  factory TransacaoFinanceira.fromJson(Map<String, dynamic> json) {
    return TransacaoFinanceira(
      id: json['id'],
      descricao: json['descricao'],
      valor: double.parse(json['valor'].toString()),
      tipo: json['tipo'],
      dataVencimento: DateTime.parse(json['data_vencimento']),
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'])
          : null,
      categoriaNome: json['categoria']?['nome'] ?? 'Geral',
      pacienteNome: json['paciente']?['nome_completo'],
      usuarioBaixaId: json['usuario_lancamento_id'], 
    );
  }
}

// --- O SERVIÇO ---

class FinanceiroService with ChangeNotifier {
  // A variável é privada (_authService)
  final AuthService _authService;
  FinanceiroService(this._authService);

  // Controle local do Caixa
  CaixaDiario? _caixaAtual;
  CaixaDiario? get caixaAtual => _caixaAtual;
  bool get isCaixaAberto => _caixaAtual?.status == 'ABERTO';

  // --- MÉTODOS DE CAIXA ---

  Future<void> verificarStatusCaixa() async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final url = Uri.parse('$baseUrl/caixas/status/hoje'); // Ajuste se a rota mudou no backend
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty && response.body != "null" && response.body != "") {
          final data = json.decode(response.body);
          _caixaAtual = CaixaDiario.fromJson(data);
        } else {
          _caixaAtual = null;
        }
      } else {
        _caixaAtual = null;
      }
      notifyListeners(); 
    } catch (e) {
      print("Erro ao verificar status do caixa: $e");
      _caixaAtual = null;
      notifyListeners();
    }
  }

  Future<void> abrirCaixa(double saldoInicial) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/caixas/abrir');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'saldo_inicial': saldoInicial}),
    );

    if (response.statusCode == 201) {
      _caixaAtual = CaixaDiario.fromJson(json.decode(response.body));
      notifyListeners();
    } else {
      throw Exception('Falha ao abrir o caixa: ${response.body}');
    }
  }

  Future<void> fecharCaixa(double saldoFinal) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/caixas/fechar');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'saldo_final': saldoFinal}),
    );

    if (response.statusCode == 200) {
      _caixaAtual = null; // Caixa fechado
      notifyListeners();
    } else {
      throw Exception('Falha ao fechar o caixa: ${response.body}');
    }
  }

  // --- MÉTODOS FINANCEIROS ---

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

  Future<List<TransacaoFinanceira>> getTransacoes() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/transacoes-financeiras');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      final lista = jsonList.map((json) => TransacaoFinanceira.fromJson(json)).toList();
      lista.sort((a, b) => b.dataVencimento.compareTo(a.dataVencimento));
      return lista;
    } else {
      throw Exception('Falha ao carregar transações.');
    }
  }

  Future<void> addTransacao({
    required String descricao,
    required double valor,
    required String tipo,
    required DateTime dataVencimento,
    required int categoriaId,
    int? pacienteId,
    bool repetir = false,
    int parcelas = 1,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/transacoes-financeiras');

    int qtd = repetir ? parcelas : 1;

    for (int i = 0; i < qtd; i++) {
      DateTime dataParcela = DateTime(
        dataVencimento.year,
        dataVencimento.month + i,
        dataVencimento.day,
      );

      String descFinal = descricao;
      if (repetir && parcelas > 1) {
        descFinal = "$descricao (${i + 1}/$parcelas)";
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'descricao': descFinal,
          'valor': valor,
          'tipo': tipo,
          'data_vencimento': dataParcela.toIso8601String(),
          // Correção: Backend espera snake_case
          'categoria_id': categoriaId, 
          'paciente_id': pacienteId,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Falha ao salvar transação ${i+1}.');
      }
    }
  }

  Future<void> marcarComoPaga(int transacaoId) async {
    if (!isCaixaAberto) {
      throw Exception('Você precisa ABRIR O CAIXA antes de movimentar dinheiro.');
    }

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
        'data_pagamento': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao marcar como paga.');
    }
  }

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
        'tipo': tipo.name, 
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar categoria.');
    }
  }

  // --- NOVOS MÉTODOS CORRIGIDOS ---

  Future<void> editarTransacao({
    required int id,
    required String descricao,
    required double valor,
    required String tipo,
    required int categoriaId, // Alterado para int para bater com o backend
    required String formaPagamento,
  }) async {
    // CORREÇÃO: Usando _authService (privado)
    final token = await _authService.getToken(); 
    
    final url = Uri.parse('$baseUrl/transacoes-financeiras/$id');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "descricao": descricao,
          "valor": valor,
          "tipo": tipo,
          // Correção: Enviando como categoria_id (snake_case)
          "categoria_id": categoriaId, 
          "forma_pagamento": formaPagamento,
        }),
      );

      if (response.statusCode != 200) {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro ao editar transação.';
        throw Exception(erroMsg);
      }
      
      notifyListeners(); 
    } catch (e) {
      rethrow;
    }
  }

  Future<void> excluirTransacao(int id) async {
    // CORREÇÃO: Usando _authService (privado)
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/transacoes-financeiras/$id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro ao excluir transação.';
        throw Exception(erroMsg);
      }
      
      notifyListeners(); 
    } catch (e) {
      rethrow;
    }
  }
}