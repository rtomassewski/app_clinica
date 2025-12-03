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
  // --- NOVO CAMPO: TIPO ---
  final String tipo;

  Produto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.unidadeMedida,
    required this.estoque,
    required this.estoqueMinimo,
    required this.valor,
    required this.tipo,
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
      
      // --- LÊ O TIPO (Se vier nulo, assume FARMACIA) ---
      tipo: json['tipo'] ?? 'FARMACIA',
    );
  }
}

class EstoqueService with ChangeNotifier {
  final AuthService authService;
  List<Produto> _produtos = [];

  EstoqueService(this.authService);

  List<Produto> get produtos => _produtos;

  // --- BUSCAR PRODUTOS (FILTRADO POR FARMACIA) ---
  Future<List<Produto>> getProdutos() async {
    final token = await authService.getToken();
    
    // --- CORREÇÃO: Adicionado filtro ?tipo=FARMACIA ---
    // Isso impede que itens da Loja apareçam na tela de Estoque
    final url = Uri.parse('$baseUrl/produtos?tipo=FARMACIA');

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
        notifyListeners(); // Atualiza a tela
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

  // --- ADICIONAR PRODUTO (MARCADO COMO FARMACIA) ---
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
        
        // --- CORREÇÃO: Força o tipo FARMACIA ---
        "tipo": "FARMACIA",
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
        // Recarrega a lista para mostrar o novo item
        await getProdutos(); 
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

  // --- REGISTRA ENTRADA DE ESTOQUE (Mantido Igual) ---
  Future<bool> addEntradaEstoque({
    required int produtoId,
    required int quantidade,
    String? lote,
    String? dataValidade,
  }) async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/entradas-estoque');

    final body = jsonEncode({
      "produtoId": produtoId,
      "quantidade": quantidade,
      "lote": lote,
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
        // Atualiza a lista para refletir a nova quantidade
        await getProdutos();
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