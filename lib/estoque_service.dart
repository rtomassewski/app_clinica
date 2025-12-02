// lib/estoque_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class Produto {
  final int id;
  final String nome;
  final String? descricao;
  final String unidadeMedida;
  final int estoque;
  final int estoqueMinimo;
  final double valor;

  Produto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.unidadeMedida,
    required this.estoque,
    required this.estoqueMinimo,
    required this.valor,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic value) {
      if (value is num) return value;
      if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
      return 0;
    }

    return Produto(
      id: (json['id'] as int?) ?? 0,
      nome: (json['nome'] as String?) ?? 'Produto Sem Nome',
      descricao: json['descricao'] as String?,
      unidadeMedida: (json['unidade_medida'] as String?) ?? 'UNIDADE',
      
      estoque: parseNum(json['estoque'] ?? json['quantidade_estoque']).toInt(),
      estoqueMinimo: parseNum(json['estoque_minimo']).toInt(),
      valor: parseNum(json['valor']).toDouble(), 
    );
  }
}

class EstoqueService with ChangeNotifier {
  final AuthService authService;
  List<Produto> _produtos = [];

  EstoqueService(this.authService);

  List<Produto> get produtos => _produtos;

  Future<List<Produto>> getProdutos() async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/produtos');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(response.body);
        _produtos = dados.map((json) => Produto.fromJson(json)).toList();
        return _produtos;
      } else {
        print('Erro ao buscar produtos: ${response.statusCode}');
        throw Exception('Falha ao carregar produtos: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro getProdutos: $e');
      rethrow;
    }
  }

  Future<bool> addProduto({
    required String nome, 
    required String unidade, 
    required int estoqueMinimo,
    required double valor, 
    String? descricao,
  }) async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/produtos');

    try {
      final body = jsonEncode({
        "nome": nome,
        "descricao": descricao, 
        "unidade_medida": unidade,
        "estoque_minimo": estoqueMinimo,
        "valor": valor, 
      });

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        return true; 
      } else {
        print('Erro ao criar produto: ${response.body}');
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro desconhecido.';
        throw Exception('Erro ${response.statusCode}: $erroMsg');
      }
    } catch (e) {
      print('Erro addProduto: $e');
      rethrow;
    }
  }

  // --- NOVO MÉTODO: REGISTRA ENTRADA DE ESTOQUE ---
  Future<bool> addEntradaEstoque({
    required int produtoId,
    required int quantidade,
    String? lote,
    String? dataValidade,
  }) async {
    final token = await authService.getToken();
    // Endpoint do Backend: POST /entradas-estoque
    final url = Uri.parse('$baseUrl/entradas-estoque');

    // Mapeia os dados do modal para o DTO do Backend
    final body = jsonEncode({
      "produtoId": produtoId,
      "quantidade": quantidade,
      "lote": lote,
      // O backend espera AAAA-MM-DD
      "data_validade": dataValidade, 
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        // A transação foi um sucesso no Backend
        return true;
      } else {
        print('Erro ao registrar entrada: ${response.body}');
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro desconhecido ao dar entrada.';
        throw Exception('Erro ${response.statusCode}: $erroMsg');
      }
    } catch (e) {
      print('Erro addEntradaEstoque: $e');
      rethrow;
    }
  }
}