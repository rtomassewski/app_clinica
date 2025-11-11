// lib/gestao_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class Papel {
  final int id;
  final String nome;

  Papel({required this.id, required this.nome});
}

// Modelo para o usuário (da lista GET /usuarios)
class UsuarioLista {
  final int id;
  final String nomeCompleto;
  final String email;
  final bool ativo;
  final String papel;

  UsuarioLista({
    required this.id,
    required this.nomeCompleto,
    required this.email,
    required this.ativo,
    required this.papel,
  });

  factory UsuarioLista.fromJson(Map<String, dynamic> json) {
    return UsuarioLista(
      id: json['id'],
      nomeCompleto: json['nome_completo'],
      email: json['email'],
      ativo: json['ativo'],
      papel: json['papel']['nome'], // Vem do 'include' da API
    );
  }
}

class GestaoService {
  final AuthService _authService;
  GestaoService(this._authService);

  // GET /usuarios
  Future<List<UsuarioLista>> getUsuarios() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/usuarios');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => UsuarioLista.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar usuários.');
    }
  }

  // POST /usuarios
  Future<void> addUsuario({
    required String nome,
    required String email,
    required String senha,
    required int papelId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final clinicaId = _authService.clinicaId; // 1. Pega o ID do Admin logado
    if (clinicaId == null) throw Exception('Erro: ID da clínica não encontrado.');

    final url = Uri.parse('$baseUrl/usuarios');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome_completo': nome,
        'email': email,
        'senha': senha,
        'papelId': papelId,
        'clinicaId': clinicaId,
      }),
      
    );

    if (response.statusCode == 409) { // Conflito (e-mail)
      throw Exception('Este e-mail já está em uso.');
    }
    if (response.statusCode != 201) {
      throw Exception('Falha ao criar usuário. Status: ${response.statusCode}');
    }
  }
  // PATCH /usuarios/:id
  Future<void> updateUsuario({
    required int usuarioId,
    required String nome,
    required int papelId,
    required bool ativo,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/usuarios/$usuarioId');
    
    final response = await http.patch( // Método PATCH
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      // (O DTO do back-end aceita 'nome_completo', 'papelId' e 'ativo')
      body: json.encode({
        'nome_completo': nome,
        'papelId': papelId,
        'ativo': ativo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar usuário.');
    }
  }

  // DELETE /usuarios/:id (Soft Delete)
  Future<void> desativarUsuario(int usuarioId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/usuarios/$usuarioId');
    
    final response = await http.delete( // Método DELETE
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 403) {
      throw Exception('Erro: Um admin não pode desativar a si mesmo.');
    }
    if (response.statusCode != 200) {
      throw Exception('Falha ao desativar usuário.');
    }
  }
}