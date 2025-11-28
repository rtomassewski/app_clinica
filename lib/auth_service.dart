// lib/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart'; 

enum StatusLicenca { ATIVA, INADIMPLENTE, CANCELADA, TESTE }
enum TipoPlano { TESTE, BASICO, GESTAO, ENTERPRISE }

class Usuario {
  final int id;
  final String nomeCompleto;
  final String email;
  final String papel;

  Usuario({
    required this.id,
    required this.nomeCompleto,
    required this.email,
    required this.papel,
  });
}

class AuthService with ChangeNotifier {
  final String baseUrl = "https://thomasmedsoft-api.onrender.com"; 
  final _storage = const FlutterSecureStorage();

  String? _token;
  Usuario? _usuario; 
  dynamic _clinicaConfig; 
  bool _isAuthenticated = false;

  StatusLicenca _licencaStatus = StatusLicenca.TESTE;
  TipoPlano _licencaPlano = TipoPlano.TESTE;
  int _clinicaId = 0;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  Usuario? get usuarioLogado => _usuario;
  String get userName => _usuario?.nomeCompleto ?? '';
  int get clinicaId => _clinicaId;
  int get papelId => 0; 
  dynamic get clinicaConfig => _clinicaConfig;
  StatusLicenca get licencaStatus => _licencaStatus;
  TipoPlano get licencaPlano => _licencaPlano;

  // Roles
  bool get isAdmin => _usuario?.papel == 'ADMINISTRADOR';
  bool get isGestor => _usuario?.papel == 'COORDENADOR' || _usuario?.papel == 'ADMINISTRADOR';
  bool get isEnfermagem => _usuario?.papel == 'ENFERMEIRO' || _usuario?.papel == 'TECNICO';
  bool get isAtendente => _usuario?.papel == 'RECEPCIONISTA' || _usuario?.papel == 'ATENDENTE';
  bool get podeAprazar => isEnfermagem || isAdmin;

  // --- LOGIN COM LOGS ---
  Future<bool> login(String email, String senha) async {
    print("--- INICIANDO LOGIN ---");
    final url = Uri.parse('$baseUrl/auth/login');
    
    try {
      print("Enviando requisição para: $url");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      print("Status Code recebido: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("Login Sucesso! Token recebido.");
        
        _token = data['access_token'];
        await _storage.write(key: 'jwt_token', value: _token);

        if (data.containsKey('usuario')) {
          final uData = data['usuario'];
          _clinicaId = uData['clinicaId'] ?? 0;
          
          String nomePapel = '';
          if (uData['papel'] != null) {
            if (uData['papel'] is Map) {
              nomePapel = uData['papel']['nome'];
            } else {
              nomePapel = uData['papel'];
            }
          } else if (uData['papelId'] != null) {
            nomePapel = _traduzirPapel(uData['papelId']);
          }

          _usuario = Usuario(
            id: uData['id'],
            nomeCompleto: uData['nome_completo'] ?? 'Usuário',
            email: uData['email'],
            papel: nomePapel,
          );

          if (uData['clinica'] != null) {
            _clinicaConfig = uData['clinica'];
          }
        }

        _licencaStatus = StatusLicenca.ATIVA; 
        _licencaPlano = TipoPlano.ENTERPRISE;

        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        print("Login falhou. Resposta: ${response.body}");
        await logout(); // Limpa sujeira
        return false;
      }
    } catch (e) {
      print("ERRO EXCEPTION NO LOGIN: $e");
      await logout();
      return false;
    }
  }

  String _traduzirPapel(int id) {
    switch (id) {
      case 1: return 'ADMINISTRADOR';
      case 2: return 'MEDICO';
      case 3: return 'DENTISTA';
      case 4: return 'PSICOLOGO';
      case 5: return 'ENFERMEIRO';
      case 6: return 'TERAPEUTA';
      case 7: return 'COORDENADOR';
      case 8: return 'TECNICO';
      case 11: return 'RECEPCIONISTA';
      case 28: return 'PSIQUIATRA';
      case 29: return 'NUTRICIONISTA';
      case 30: return 'FISIOTERAPEUTA';
      default: return 'DESCONHECIDO';
    }
  }

  Future<void> logout() async {
    print("Fazendo Logout...");
    _token = null;
    _usuario = null;
    _isAuthenticated = false;
    await _storage.deleteAll();
    notifyListeners();
    print("Logout concluído.");
  }

  // Registro Trial
  Future<void> registerTrial({
    required String nomeAdmin, 
    required String email, 
    required String senha, 
    required String nomeFantasia,
    String? cnpj
  }) async {
    final url = Uri.parse('$baseUrl/auth/register-trial');
    final response = await http.post(
       url,
       headers: {'Content-Type': 'application/json'},
       body: jsonEncode({
         'nome_completo': nomeAdmin,
         'email': email,
         'senha': senha,
         'nome_clinica': nomeFantasia,
         'cnpj': cnpj
       })
    );
    if (response.statusCode != 201) throw Exception('Falha: ${response.body}');
  }

  Future<void> updatePerfil({
    String? nome, 
    String? email, 
    String? senha,
    String? registroConselho,
    String? assinaturaUrl
  }) async {
     if (_usuario != null && nome != null) {
       _usuario = Usuario(
         id: _usuario!.id, 
         nomeCompleto: nome, 
         email: email ?? _usuario!.email, 
         papel: _usuario!.papel
       );
       notifyListeners();
     }
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
       _token = token;
       _isAuthenticated = true;
       notifyListeners();
    }
  }
}