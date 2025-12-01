// lib/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart'; 

// --- CLASSE DE CONFIGURAÇÃO (Deve ficar aqui ou num arquivo separado) ---
class ClinicaConfig {
  final int id;
  final String? nomeFantasia;
  final String? razaoSocial;
  final String? cnpj;
  final String? telefone;
  final String? endereco;
  final String? logoUrl;
  final String? corPrimaria;

  ClinicaConfig({
    required this.id,
    this.nomeFantasia,
    this.razaoSocial,
    this.cnpj,
    this.telefone,
    this.endereco,
    this.logoUrl,
    this.corPrimaria,
  });

  factory ClinicaConfig.fromJson(Map<String, dynamic> json) {
    return ClinicaConfig(
      id: json['id'],
      nomeFantasia: json['nome_fantasia'] ?? json['nome'] ?? json['nome_clinica'], 
      razaoSocial: json['razao_social'],
      cnpj: json['cnpj'],
      telefone: json['telefone'],
      endereco: json['endereco'],
      logoUrl: json['logo_url'],
      corPrimaria: json['cor_primaria'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome_fantasia': nomeFantasia,
      'razao_social': razaoSocial,
      'cnpj': cnpj,
      'telefone': telefone,
      'endereco': endereco,
      'logo_url': logoUrl,
      'cor_primaria': corPrimaria,
    };
  }
}

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
  ClinicaConfig? _clinicaConfig; // Variável tipada corretamente
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
  
  // CORREÇÃO: Getter tipado corretamente
  ClinicaConfig? get clinicaConfig => _clinicaConfig;
  
  StatusLicenca get licencaStatus => _licencaStatus;
  TipoPlano get licencaPlano => _licencaPlano;

  // --- GETTERS DE PERMISSÃO (ROLES) ---
  bool get isAdmin {
    final p = usuarioLogado?.papel?.toUpperCase().trim() ?? '';
    return p == 'ADMINISTRADOR'; 
  }
  bool get isGestor {
    final p = usuarioLogado?.papel?.toUpperCase().trim() ?? '';
    return p == 'GESTOR' || p == 'COORDENADOR'; 
  }
  bool get isAtendente {
    final p = usuarioLogado?.papel?.toUpperCase().trim() ?? '';
    return p == 'ATENDENTE' || p == 'RECEPCIONISTA'; 
  }
  bool get isEnfermagem {
    final p = usuarioLogado?.papel?.toUpperCase().trim() ?? '';
    return p == 'ENFERMEIRO' || p == 'TECNICO' || p == 'AUXILIAR';
  }
  bool get isMedico => usuarioLogado?.papel?.toUpperCase().trim() == 'MEDICO';
  bool get isDentista => usuarioLogado?.papel?.toUpperCase().trim() == 'DENTISTA';
  bool get isPsicologo => usuarioLogado?.papel?.toUpperCase().trim() == 'PSICOLOGO';
  
  bool get podeAprazar => isEnfermagem || isMedico || isAdmin;

  // --- LOGIN ---
  Future<bool> login(String email, String senha) async {
    print("--- INICIANDO LOGIN ---");
    final url = Uri.parse('$baseUrl/auth/login');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        await _storage.write(key: 'jwt_token', value: _token);

        if (data.containsKey('usuario')) {
          final uData = data['usuario'];
          _processarDadosUsuario(uData); // Usamos o helper para evitar repetição
        }

        _licencaStatus = StatusLicenca.ATIVA; 
        _licencaPlano = TipoPlano.ENTERPRISE;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        await logout(); 
        return false;
      }
    } catch (e) {
      print("ERRO EXCEPTION NO LOGIN: $e");
      await logout();
      return false;
    }
  }

  // --- AUTO LOGIN ---
  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    
    if (token != null) {
       _token = token;
       final sucesso = await _fetchPerfil();
       
       if (sucesso) {
         _isAuthenticated = true;
         notifyListeners();
       } else {
         await logout();
       }
    }
  }

  Future<bool> _fetchPerfil() async {
    if (_token == null) return false;

    try {
      final url = Uri.parse('$baseUrl/auth/perfil');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $_token'});

      if (response.statusCode == 200) {
        final uData = jsonDecode(response.body);
        _processarDadosUsuario(uData); // Helper
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- HELPER PARA PROCESSAR DADOS (Corrige o erro de duplicação) ---
  void _processarDadosUsuario(Map<String, dynamic> uData) {
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

    // --- AQUI ESTAVA O SEU ERRO ---
    // Antes: _clinicaConfig = uData['clinica'];
    // Agora: Usamos o .fromJson()
    if (uData['clinica'] != null) {
      _clinicaConfig = ClinicaConfig.fromJson(uData['clinica']);
    }
    // -----------------------------
  }

  String _traduzirPapel(int id) {
    switch (id) {
      case 1: return 'ADMINISTRADOR';
      case 2: return 'MEDICO';
      case 3: return 'PSICOLOGO';
      case 4: return 'ENFERMEIRO';
      case 5: return 'TERAPEUTA';
      case 6: return 'COORDENADOR';
      case 7: return 'TECNICO';
      case 8: return 'ATENDENTE';
      case 275: return 'DENTISTA';
      case 300: return 'PSIQUIATRA';
      case 301: return 'NUTRICIONISTA';
      case 302: return 'FISIOTERAPEUTA';
      default: return 'DESCONHECIDO';
    }
  }

  Future<void> logout() async {
    _token = null;
    _usuario = null;
    _clinicaConfig = null;
    _isAuthenticated = false;
    await _storage.deleteAll();
    notifyListeners();
  }

  Future<void> registerTrial({required String nomeAdmin, required String email, required String senha, required String nomeFantasia, String? cnpj}) async {
    final url = Uri.parse('$baseUrl/auth/register-trial');
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'nome_completo': nomeAdmin, 'email': email, 'senha': senha, 'nome_clinica': nomeFantasia, 'cnpj': cnpj}));
    if (response.statusCode != 201) throw Exception('Falha: ${response.body}');
  }

 Future<void> updatePerfil({
    String? nome,
    String? email,
    String? senha,
    String? registroConselho,
    String? assinaturaUrl, // <--- ADICIONADO AGORA
  }) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null || _usuario == null) return;

    final url = Uri.parse('$baseUrl/usuarios/${_usuario!.id}');
    
    // Montamos o JSON apenas com o que foi alterado
    Map<String, dynamic> dadosParaEnviar = {};
    
    if (nome != null) dadosParaEnviar['nome_completo'] = nome;
    if (email != null) dadosParaEnviar['email'] = email;
    if (senha != null && senha.isNotEmpty) dadosParaEnviar['senha'] = senha;
    if (registroConselho != null) dadosParaEnviar['registro_conselho'] = registroConselho;
    
    // Mapeia para o campo correto do Backend (geralmente snake_case)
    if (assinaturaUrl != null) dadosParaEnviar['assinatura_url'] = assinaturaUrl;

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(dadosParaEnviar),
      );

      if (response.statusCode == 200) {
        // Atualiza os dados locais
        _usuario = Usuario(
          id: _usuario!.id,
          nomeCompleto: nome ?? _usuario!.nomeCompleto,
          email: email ?? _usuario!.email,
          papel: _usuario!.papel,
        );
        notifyListeners();
      } else {
        throw Exception('Erro ao atualizar perfil: ${response.body}');
      }
    } catch (e) {
      print("Erro no updatePerfil: $e");
      throw e;
    }
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    return await _storage.read(key: 'jwt_token');
  }
}