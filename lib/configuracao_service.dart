// lib/configuracao_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// 1. Modelo de Dados para a Clínica (lido do AuthService)
class ClinicaConfig {
  final int id;
  final String nomeFantasia;
  final String? logoUrl;
  final String? endereco;
  final String? telefone;

  ClinicaConfig({
    required this.id,
    required this.nomeFantasia,
    this.logoUrl,
    this.endereco,
    this.telefone,
  });

  // (Usado para ler os dados que o AuthService salvou)
  factory ClinicaConfig.fromUsuarioLogin(Map<String, dynamic> clinicaJson) {
    return ClinicaConfig(
      id: clinicaJson['id'],
      nomeFantasia: clinicaJson['nome_fantasia'],
      logoUrl: clinicaJson['logo_url'],
      endereco: clinicaJson['endereco'],
      telefone: clinicaJson['telefone'],
    );
  }
}

// --- O SERVIÇO ---
class ConfiguracaoService {
  final AuthService _authService;
  ConfiguracaoService(this._authService);

  // 2. PATCH /clinicas/:id
  Future<void> updateClinica(
    int clinicaId,
    Map<String, dynamic> data,
  ) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/clinicas/$clinicaId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 403) {
      throw Exception('Você não tem permissão para editar esta clínica.');
    }
    if (response.statusCode != 200) {
      throw Exception('Falha ao salvar as configurações.');
    }
  }
}