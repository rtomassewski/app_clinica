// lib/estoque_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// (Este enum precisa bater com o do Prisma)
enum UnidadeMedida {
  UNIDADE,
  CAIXA,
  FRASCO,
  ML
}

// Modelo para a lista principal (GET /produtos)
class ProdutoEstoque {
  final int id;
  final String nome;
  final int quantidadeEstoque;
  final int estoqueMinimo;
  final UnidadeMedida unidadeMedida;

  ProdutoEstoque({
    required this.id,
    required this.nome,
    required this.quantidadeEstoque,
    required this.estoqueMinimo,
    required this.unidadeMedida,
  });

  static UnidadeMedida _parseUnidade(String? unidade) {
    switch (unidade) {
      case 'CAIXA':
        return UnidadeMedida.CAIXA;
      case 'FRASCO':
        return UnidadeMedida.FRASCO;
      case 'ML':
        return UnidadeMedida.ML;
      case 'UNIDADE':
      default:
        return UnidadeMedida.UNIDADE;
    }
  }

  factory ProdutoEstoque.fromJson(Map<String, dynamic> json) {
    return ProdutoEstoque(
      id: json['id'],
      nome: json['nome'],
      quantidadeEstoque: json['quantidade_estoque'],
      estoqueMinimo: json['estoque_minimo'],
      unidadeMedida: _parseUnidade(json['unidade_medida']),
    );
  }
}

// --- O SERVIÇO ---

class EstoqueService {
  final AuthService _authService;
  EstoqueService(this._authService);

  // GET /produtos
  Future<List<ProdutoEstoque>> getProdutos() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/produtos');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => ProdutoEstoque.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar produtos.');
    }
  }

  // POST /produtos (Criar novo item no catálogo)
  Future<void> addProduto({
    required String nome,
    required UnidadeMedida unidade,
    int? estoqueMinimo,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/produtos');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome': nome,
        'unidade_medida': unidade.name, // "UNIDADE", "CAIXA", etc.
        'estoque_minimo': estoqueMinimo,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar produto.');
    }
  }

  // POST /entradas-estoque (Dar entrada)
  Future<void> addEntradaEstoque({
    required int produtoId,
    required int quantidade,
    String? lote,
    String? dataValidade, // Formato "AAAA-MM-DD"
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/entradas-estoque');
    
    // Converte a data (se houver) para o formato ISO
    String? dataValidadeISO;
    if (dataValidade != null && dataValidade.isNotEmpty) {
      // Pequena validação para garantir que a data está em formato AAAA-MM-DD
      try {
        dataValidadeISO = DateTime.parse(dataValidade).toIso8601String();
      } catch (e) {
        throw Exception('Formato de data de validade inválido. Use AAAA-MM-DD.');
      }
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'produtoId': produtoId,
        'quantidade': quantidade,
        'lote': lote,
        'data_validade': dataValidadeISO,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao dar entrada no estoque.');
    }
  }
}