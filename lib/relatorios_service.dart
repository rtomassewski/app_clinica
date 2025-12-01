// lib/relatorios_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// --- MODELOS DE DADOS DO DASHBOARD ---

class LeitosData {
  final int total;
  final int ocupados;
  final int disponiveis;
  final double taxaOcupacao;

  LeitosData({required this.total, required this.ocupados, required this.disponiveis, required this.taxaOcupacao});

  factory LeitosData.fromJson(Map<String, dynamic> json) {
    return LeitosData(
      total: json['total'] ?? 0,
      ocupados: json['ocupados'] ?? 0,
      disponiveis: json['disponiveis'] ?? 0,
      taxaOcupacao: double.tryParse(json['taxaOcupacao'].toString()) ?? 0.0,
    );
  }
}

class PacientesData {
  final int ativos;
  final int admissoesNoMes;

  PacientesData({required this.ativos, required this.admissoesNoMes});

  factory PacientesData.fromJson(Map<String, dynamic> json) {
    return PacientesData(
      ativos: json['ativos'] ?? 0,
      admissoesNoMes: json['admissoesNoMes'] ?? 0,
    );
  }
}

class FinanceiroData {
  final double receitaMes;
  final double despesaMes;
  final double saldoMes;

  FinanceiroData({required this.receitaMes, required this.despesaMes, required this.saldoMes});

  factory FinanceiroData.fromJson(Map<String, dynamic> json) {
    return FinanceiroData(
      receitaMes: double.tryParse(json['receitaMes'].toString()) ?? 0.0,
      despesaMes: double.tryParse(json['despesaMes'].toString()) ?? 0.0,
      saldoMes: double.tryParse(json['saldoMes'].toString()) ?? 0.0,
    );
  }
}

class DashboardData {
  final LeitosData leitos;
  final PacientesData pacientes;
  final FinanceiroData financeiro;

  DashboardData({required this.leitos, required this.pacientes, required this.financeiro});

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      leitos: LeitosData.fromJson(json['leitos'] ?? {}),
      pacientes: PacientesData.fromJson(json['pacientes'] ?? {}),
      financeiro: FinanceiroData.fromJson(json['financeiro'] ?? {}),
    );
  }
}

// --- O SERVICE ---

class RelatoriosService {
  final AuthService _authService;
  RelatoriosService(this._authService);

  Future<DashboardData> getDashboard() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    // Ajuste a rota se necessário (ex: /relatorios/dashboard)
    final url = Uri.parse('$baseUrl/relatorios/dashboard'); 
    
    final response = await http.get(
      url, 
      headers: {'Authorization': 'Bearer $token'}
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return DashboardData.fromJson(data);
    } else {
      throw Exception('Falha ao carregar dashboard: ${response.statusCode}');
    }
  }
}