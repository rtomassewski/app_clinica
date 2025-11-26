import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart'; // Certifique-se de que a baseUrl está aqui

class Procedimento {
  final int id;
  final String nome;
  final String? descricao;
  final double valor;
  final bool ativo;

  Procedimento({
    required this.id,
    required this.nome,
    this.descricao,
    required this.valor,
    required this.ativo,
  });

  factory Procedimento.fromJson(Map<String, dynamic> json) {
    return Procedimento(
      id: json['id'],
      nome: json['nome'],
      descricao: json['descricao'],
      // Garante que o valor venha como double mesmo se a API mandar int
      valor: (json['valor'] as num).toDouble(), 
      ativo: json['ativo'] ?? true,
    );
  }
}

class ProcedimentoService {
  final AuthService _authService;
  // Se não tiver api_config, troque pela string direta da URL
  final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 

  ProcedimentoService(this._authService);

  // LISTAR TODOS
  Future<List<Procedimento>> getProcedimentos() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/procedimentos'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((json) => Procedimento.fromJson(json)).toList();
    } else {
      throw Exception('Erro ao carregar procedimentos');
    }
  }

  // CRIAR
  Future<void> addProcedimento(String nome, String valorStr, String? descricao) async {
    final token = await _authService.getToken();
    
    // Converte "150,00" para 150.00
    double valor = double.parse(valorStr.replaceAll(',', '.'));

    final response = await http.post(
      Uri.parse('$baseUrl/procedimentos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'nome': nome,
        'valor': valor,
        'descricao': descricao,
        'ativo': true
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Erro ao criar procedimento');
    }
  }

  // ATUALIZAR
  Future<void> updateProcedimento(int id, String nome, String valorStr, String? descricao, bool ativo) async {
    final token = await _authService.getToken();
    double valor = double.parse(valorStr.replaceAll(',', '.'));

    final response = await http.patch(
      Uri.parse('$baseUrl/procedimentos/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'nome': nome,
        'valor': valor,
        'descricao': descricao,
        'ativo': ativo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar procedimento');
    }
  }
}