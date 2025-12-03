// lib/loja_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// REUTILIZANDO O MODELO DO ESTOQUE
class Produto {
  final int id;
  final String nome;
  final String? descricao;
  final String unidadeMedida;
  final int estoque;
  final int estoqueMinimo;
  final double valor;
  final bool ativo; 
  final String tipo;

  Produto({
    required this.id,
    required this.tipo, // <--- CORREÇÃO: Adicionada a vírgula que faltava
    required this.nome,
    this.descricao,
    required this.unidadeMedida,
    required this.estoque,
    required this.estoqueMinimo,
    required this.valor,
    required this.ativo,
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
      ativo: json['ativo'] ?? true,
      tipo: json['tipo'] ?? 'FARMACIA',
    );
  }
}

class LojaService with ChangeNotifier {
  final AuthService authService;
  List<Produto> _produtosLoja = [];

  LojaService(this.authService);

  List<Produto> get produtosLoja => _produtosLoja;

  // --- 1. CRUD DE PRODUTOS (Criação e Edição) ---

  Future<void> saveProduto({
    int? id,
    required String nome,
    required double valor,
    required String unidade,
    required int estoqueMinimo,
  }) async {
    final token = await authService.getToken();
    final isUpdating = id != null;
    
    // Define a URL baseada se é edição ou criação
    final endpoint = isUpdating ? '/produtos/$id' : '/produtos';
    final url = Uri.parse('$baseUrl$endpoint');

    final body = jsonEncode({
      "nome": nome,
      "valor": valor,
      "unidade_medida": unidade,
      "estoque_minimo": estoqueMinimo,
      "tipo": "LOJA", // <--- CORREÇÃO: Força o tipo LOJA para não misturar com farmácia
    });

    try {
      http.Response response;

      // <--- CORREÇÃO: Usa o método HTTP correto (POST ou PATCH)
      if (isUpdating) {
        response = await http.patch(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      } else {
        response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Se a operação for bem-sucedida, atualize a lista.
        await fetchProdutos();
      } else {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro desconhecido.';
        throw Exception(erroMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- 2. BUSCA DE PRODUTOS ---

  Future<List<Produto>> fetchProdutos() async {
    final token = await authService.getToken();
    
    // <--- CORREÇÃO: Adicionado filtro ?tipo=LOJA na URL
    final url = Uri.parse('$baseUrl/produtos?tipo=LOJA');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(response.body);
        _produtosLoja = dados.map((json) => Produto.fromJson(json)).toList();
        notifyListeners(); // Notifica a tela para atualizar a lista
        return _produtosLoja;
      } else {
        throw Exception('Falha ao carregar produtos: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- 3. ADICIONAR CRÉDITOS ---

  Future<void> adicionarCredito({
    required int pacienteId, 
    required double valor,
  }) async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/loja/credito');

    final body = jsonEncode({
      "pacienteId": pacienteId,
      "valor": valor,
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

      if (response.statusCode != 201) {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro desconhecido ao adicionar crédito.';
        throw Exception(erroMsg);
      }
      
      notifyListeners(); 
    } catch (e) {
      rethrow;
    }
  }

  // --- 4. REALIZAR VENDA ---

  Future<void> realizarVenda({
    required int pacienteId,
    required List<Map<String, dynamic>> itens,
  }) async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/loja/venda');

    final body = jsonEncode({
      "pacienteId": pacienteId,
      "itens": itens,
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

      if (response.statusCode != 201) {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro na transação de venda.';
        throw Exception(erroMsg);
      }
      
      notifyListeners(); 
      await fetchProdutos(); // Atualiza o estoque logo após a venda
    } catch (e) {
      rethrow;
    }
  }
  Future<void> adicionarEntradaEstoque({
    required int produtoId,
    required int quantidade,
  }) async {
    final token = await authService.getToken();
    final url = Uri.parse('$baseUrl/entradas-estoque');

    final body = jsonEncode({
      "produtoId": produtoId,
      "quantidade": quantidade,
      // Loja geralmente não exige lote/validade, mas se quiser pode adicionar
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

      if (response.statusCode != 201) {
        final erroMsg = jsonDecode(response.body)['message'] ?? 'Erro ao dar entrada.';
        throw Exception(erroMsg);
      }
      
      await fetchProdutos(); // Atualiza a lista para mostrar o novo estoque
    } catch (e) {
      rethrow;
    }
  }
}