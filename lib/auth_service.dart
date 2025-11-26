// lib/auth_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'api_config.dart';
import 'configuracao_service.dart';

// --- 1. CLASSE USUARIO (ADICIONADA PARA O MENU LATERAL) ---
class Usuario {
  final int id;
  final String nomeCompleto;
  final String email;
  final int papelId;
  final int? clinicaId;

  Usuario({
    required this.id,
    required this.nomeCompleto,
    required this.email,
    required this.papelId,
    this.clinicaId,
  });
}
// ---------------------------------------------------------

// --- ENUMS ---
enum StatusLicenca { ATIVA, INADIMPLENTE, CANCELADA, TESTE, DESCONHECIDO }
enum TipoPlano { BASICO, PRO, GESTAO, ENTERPRISE, TESTE, DESCONHECIDO }

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;

  // 2. OBJETO USUÁRIO (ADICIONADO)
  Usuario? _usuario; 

  // Dados da Licença
  StatusLicenca _licencaStatus = StatusLicenca.DESCONHECIDO;
  TipoPlano _licencaPlano = TipoPlano.DESCONHECIDO;

  // Dados da Clínica
  ClinicaConfig? _clinicaConfig;

  // --- GETTERS ---
  bool get isAuthenticated => _isAuthenticated;
  
  // 3. GETTER QUE O MAIN_SCREEN PROCURA (ADICIONADO)
  Usuario? get usuarioLogado => _usuario;

  // Mantivemos os getters antigos por compatibilidade, lendo do objeto _usuario
  String? get userName => _usuario?.nomeCompleto;
  int? get papelId => _usuario?.papelId;
  int? get clinicaId => _usuario?.clinicaId;
  
  StatusLicenca get licencaStatus => _licencaStatus;
  TipoPlano get licencaPlano => _licencaPlano;
  ClinicaConfig? get clinicaConfig => _clinicaConfig;

  // (Getters de Permissão baseados no ID do papel)
  bool get isAdmin { return papelId == 1; }
  bool get isEnfermagem { return papelId == 4 || papelId == 7; }
  bool get isGestor { return papelId == 1 || papelId == 6; }
  bool get podeAprazar { return papelId == 1 || papelId == 4; }
  bool get isAtendente { return papelId == 8; }

  
  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  // --- PARSERS ---
  StatusLicenca _parseStatus(String? status) {
    switch (status) {
      case 'ATIVA': return StatusLicenca.ATIVA;
      case 'INADIMPLENTE': return StatusLicenca.INADIMPLENTE;
      case 'CANCELADA': return StatusLicenca.CANCELADA;
      case 'TESTE': return StatusLicenca.TESTE;
      default: return StatusLicenca.DESCONHECIDO;
    }
  }

  TipoPlano _parsePlano(String? plano) {
    switch (plano) {
      case 'BASICO': return TipoPlano.BASICO;
      case 'PRO': return TipoPlano.PRO;
      case 'GESTAO': return TipoPlano.GESTAO;
      case 'ENTERPRISE': return TipoPlano.ENTERPRISE;
      case 'TESTE': return TipoPlano.TESTE;
      default: return TipoPlano.DESCONHECIDO;
    }
  }

  // --- LOGIN ---
  Future<bool> login(String email, String senha) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'email': email, 'senha': senha}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) { 
        final data = json.decode(response.body);
        final token = data['access_token'];
        final usuarioData = data['usuario'];
        
        // 4. POPULAR O OBJETO USUÁRIO
        _usuario = Usuario(
          id: usuarioData['id'],
          nomeCompleto: usuarioData['nome'], // A API manda 'nome', o front usa 'nomeCompleto'
          email: usuarioData['email'],
          papelId: usuarioData['papelId'],
          clinicaId: usuarioData['clinicaId'],
        );
        
        // Licença
        final licencaData = usuarioData['licenca'];
        if (licencaData != null) {
          _licencaStatus = _parseStatus(licencaData['status']);
          _licencaPlano = _parsePlano(licencaData['plano']);
        } else {
          _licencaStatus = StatusLicenca.DESCONHECIDO;
          _licencaPlano = TipoPlano.DESCONHECIDO;
        }
        
        // Config Clínica
        final clinicaData = usuarioData['clinica'];
        if (clinicaData != null) {
          _clinicaConfig = ClinicaConfig.fromUsuarioLogin(clinicaData);
        }
        
        await _storage.write(key: 'access_token', value: token);
        _isAuthenticated = true;
        notifyListeners();
        return true;
        
      } else {
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      _isAuthenticated = false;
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    _isAuthenticated = false;
    
    // Limpar dados
    _usuario = null;
    _licencaStatus = StatusLicenca.DESCONHECIDO;
    _licencaPlano = TipoPlano.DESCONHECIDO;
    _clinicaConfig = null;
    
    notifyListeners();
  }
  
  // (Update Perfil - Opcional, mantido vazio conforme original)
  Future<void> updatePerfil({
    required String nome,
    String? registroConselho,
    String? assinaturaUrl,
  }) async {}

  // --- REGISTER TRIAL ---
  Future<void> registerTrial({
    required String nomeFantasia,
    required String cnpj,
    required String nomeAdmin,
    required String emailAdmin,
    required String senhaAdmin,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register-trial');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'nome_fantasia': nomeFantasia,
          'cnpj': cnpj,
          'nome_admin': nomeAdmin,
          'email_admin': emailAdmin,
          'senha_admin': senhaAdmin,
        }),
      );

      if (response.statusCode == 409) {
        final body = json.decode(response.body);
        throw Exception(body['message'] ?? 'E-mail ou CNPJ já está em uso.');
      }
      
      if (response.statusCode == 400) {
        final body = json.decode(response.body);
        throw Exception(body['message'] is List ? body['message'][0] : body['message'] ?? 'Dados inválidos.');
      }
      
      if (response.statusCode != 201) {
        throw Exception('Falha ao criar a conta de teste.');
      }

      final data = json.decode(response.body);
      final token = data['access_token'];
      final usuarioData = data['usuario'];
      
      // Popular Usuário no Registro também
      _usuario = Usuario(
          id: usuarioData['id'],
          nomeCompleto: usuarioData['nome'],
          email: usuarioData['email'],
          papelId: usuarioData['papelId'],
          clinicaId: usuarioData['clinicaId'],
      );
      
      final licencaData = usuarioData['licenca'];
      _licencaStatus = _parseStatus(licencaData?['status']);
      _licencaPlano = _parsePlano(licencaData?['plano']);
      
      final clinicaData = usuarioData['clinica'];
      if (clinicaData != null) {
        _clinicaConfig = ClinicaConfig.fromUsuarioLogin(clinicaData);
      }
      
      await _storage.write(key: 'access_token', value: token);
      _isAuthenticated = true;
      notifyListeners();
      
    } catch (e) {
      throw Exception('Erro no registo: $e');
    }
  }
}