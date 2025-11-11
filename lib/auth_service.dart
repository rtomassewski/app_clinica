// lib/auth_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'api_config.dart';
import 'configuracao_service.dart';

// --- ENUMS ---
enum StatusLicenca { ATIVA, INADIMPLENTE, CANCELADA, TESTE, DESCONHECIDO }
enum TipoPlano { BASICO, PRO, GESTAO, ENTERPRISE, TESTE, DESCONHECIDO } // (Certifique-se que estes batem com o seu Prisma)

// --- FIM DOS ENUMS ---

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  
  // Dados do Utilizador
  String? _userName;
  int? _papelId;
  int? _clinicaId;
  
  // Dados da Licença (CORRIGIDO)
  StatusLicenca _licencaStatus = StatusLicenca.DESCONHECIDO;
  TipoPlano _licencaPlano = TipoPlano.DESCONHECIDO; // <-- Propriedade

  // Dados da Clínica
  ClinicaConfig? _clinicaConfig;

  // --- GETTERS ---
  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  int? get papelId => _papelId;
  int? get clinicaId => _clinicaId;
  StatusLicenca get licencaStatus => _licencaStatus;
  TipoPlano get licencaPlano => _licencaPlano; // <-- Getter
  ClinicaConfig? get clinicaConfig => _clinicaConfig;

  // (Getters de Permissão)
  bool get isAdmin { return _papelId == 1; }
  bool get isEnfermagem { return _papelId == 4 || _papelId == 7; }
  bool get isGestor { return _papelId == 1 || _papelId == 6; }
  bool get podeAprazar { return _papelId == 1 || _papelId == 4; }
  bool get isAtendente { return _papelId == 8; }

  
  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  // --- PARSERS DE ENUM (CORRIGIDO) ---
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
      case 'GESTAO': return TipoPlano.GESTAO; // (Exemplo)
      case 'ENTERPRISE': return TipoPlano.ENTERPRISE; // (Exemplo)
      case 'TESTE': return TipoPlano.TESTE;
      default: return TipoPlano.DESCONHECIDO;
    }
  }
  // --- FIM DOS PARSERS ---

  Future<bool> login(String email, String senha) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'email': email, 'senha': senha}),
      );

      if (response.statusCode == 201) { 
        final data = json.decode(response.body);
        final token = data['access_token'];
        final usuarioData = data['usuario'];
        
        _userName = usuarioData['nome'];
        _papelId = usuarioData['papelId'];
        _clinicaId = usuarioData['clinicaId'];
        
        // --- CORREÇÃO: Salva o Status E o Plano ---
        final licencaData = usuarioData['licenca'];
        if (licencaData != null) {
          _licencaStatus = _parseStatus(licencaData['status']);
          _licencaPlano = _parsePlano(licencaData['plano']); // <-- SALVA O PLANO
        } else {
          _licencaStatus = StatusLicenca.DESCONHECIDO;
          _licencaPlano = TipoPlano.DESCONHECIDO;
        }
        // --- FIM DA CORREÇÃO ---
        
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
    
    _userName = null;
    _papelId = null;
    _clinicaId = null;
    _licencaStatus = StatusLicenca.DESCONHECIDO;
    _licencaPlano = TipoPlano.DESCONHECIDO; // <-- LIMPA O PLANO
    _clinicaConfig = null;
    
    notifyListeners();
  }
  
  // (O método updatePerfil não muda)
  Future<void> updatePerfil({
    required String nome,
    String? registroConselho,
    String? assinaturaUrl,
  }) async {
    // ... (código existente)
  }
}