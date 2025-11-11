// lib/relatorios_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// --- MODELOS DE DADOS PARA O JSON DO DASHBOARD ---

class PacientesData {
  final int ativos;
  final int admissoesNoMes;
  PacientesData.fromJson(Map<String, dynamic> json)
      : ativos = json['ativos'],
        admissoesNoMes = json['admissoesNoMes'];
}

class LeitosData {
  final int ocupados;
  final int disponiveis;
  final int total;
  final double taxaOcupacao;
  LeitosData.fromJson(Map<String, dynamic> json)
      : ocupados = json['ocupados'],
        disponiveis = json['disponiveis'],
        total = json['total'],
        taxaOcupacao = json['taxaOcupacao'].toDouble();
}

class FinanceiroData {
  final double receitaMes;
  final double despesaMes;
  final double saldoMes;
  FinanceiroData.fromJson(Map<String, dynamic> json)
      : receitaMes = json['receitaMes'].toDouble(),
        despesaMes = json['despesaMes'].toDouble(),
        saldoMes = json['saldoMes'].toDouble();
}

// O Modelo Principal
class DashboardData {
  final PacientesData pacientes;
  final LeitosData leitos;
  final FinanceiroData financeiro;

  DashboardData.fromJson(Map<String, dynamic> json)
      : pacientes = PacientesData.fromJson(json['pacientes']),
        leitos = LeitosData.fromJson(json['leitos']),
        financeiro = FinanceiroData.fromJson(json['financeiro']);
}

// --- O SERVIÇO ---

class RelatoriosService {
  final AuthService _authService;
  RelatoriosService(this._authService);

  // GET /relatorios/dashboard
  Future<DashboardData> getDashboard() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/relatorios/dashboard');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return DashboardData.fromJson(json);
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado ao dashboard.');
    } else {
      throw Exception('Falha ao carregar o dashboard.');
    }
  }
}