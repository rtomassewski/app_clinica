// lib/internacao_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart';

// --- MODELOS DE DADOS ---

// Modelo para a lista de Alas (GET /alas)
class Ala {
  final int id;
  final String nome;
  final String? descricao;

  Ala({required this.id, required this.nome, this.descricao});

  factory Ala.fromJson(Map<String, dynamic> json) {
    return Ala(
      id: json['id'],
      nome: json['nome'],
      descricao: json['descricao'],
    );
  }
}

// Modelo para a lista de Quartos (GET /quartos)
class Quarto {
  final int id;
  final String nome;
  final String? descricao;
  final int alaId;

  Quarto({
    required this.id,
    required this.nome,
    this.descricao,
    required this.alaId,
  });

  factory Quarto.fromJson(Map<String, dynamic> json) {
    return Quarto(
      id: json['id'],
      nome: json['nome'],
      descricao: json['descricao'],
      alaId: json['alaId'],
    );
  }
}

// Modelo para a lista de Leitos (GET /leitos)
enum StatusLeito {
  DISPONIVEL,
  OCUPADO,
  RESERVADO,
  MANUTENCAO,
  DESCONHECIDO
}

class Leito {
  final int id;
  final String nome;
  final StatusLeito status;
  final String? pacienteNome;
  final int? pacienteId; // <-- 1. ADICIONADO

  Leito({
    required this.id,
    required this.nome,
    required this.status,
    this.pacienteNome,
    this.pacienteId, // <-- 2. ADICIONADO
  });

  // Helper para converter a String da API no nosso Enum
  static StatusLeito _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'DISPONIVEL':
        return StatusLeito.DISPONIVEL;
      case 'OCUPADO':
        return StatusLeito.OCUPADO;
      case 'RESERVADO':
        return StatusLeito.RESERVADO;
      case 'MANUTENCAO':
        return StatusLeito.MANUTENCAO;
      default:
        return StatusLeito.DESCONHECIDO;
    }
  }

  factory Leito.fromJson(Map<String, dynamic> json) {
    return Leito(
      id: json['id'],
      nome: json['nome'],
      status: _parseStatus(json['status']),
      pacienteNome: json['paciente']?['nome_completo'],
      pacienteId: json['paciente']?['id'], // <-- 3. ADICIONADO
    );
  }
}
// --- FIM DOS MODELOS ---


class InternacaoService {
  final AuthService _authService;
  InternacaoService(this._authService);

  // --- ALAS ---
  Future<List<Ala>> getAlas() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/alas');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Ala.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar as Alas.');
    }
  }

  Future<void> addAla({
    required String nome,
    String? descricao,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/alas');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome': nome,
        'descricao': descricao,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar a ala. Status: ${response.statusCode}');
    }
  }

  // --- QUARTOS ---
  Future<List<Quarto>> getQuartos(int alaId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/quartos').replace(
      queryParameters: {'alaId': alaId.toString()},
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Quarto.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar os Quartos.');
    }
  }

  Future<void> addQuarto({
    required String nome,
    String? descricao,
    required int alaId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/quartos');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome': nome,
        'descricao': descricao,
        'alaId': alaId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar o quarto. Status: ${response.statusCode}');
    }
  }

  // --- LEITOS ---
  Future<List<Leito>> getLeitos(int quartoId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/leitos').replace(
      queryParameters: {'quartoId': quartoId.toString()},
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Leito.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar os Leitos.');
    }
  }

  Future<void> addLeito({
    required String nome,
    required int quartoId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/leitos');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nome': nome,
        'quartoId': quartoId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar o leito. Status: ${response.statusCode}');
    }
  }
  // GET /pacientes?semLeito=true
  Future<List<Paciente>> getPacientesSemLeito() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes').replace(
      queryParameters: {'semLeito': 'true'}, // O novo filtro
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      // (Reutilizando o modelo 'Paciente' do paciente_service.dart)
      return jsonList.map((json) => Paciente.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes disponíveis.');
    }
  }

  // PATCH /pacientes/:id/check-in
  Future<void> checkInPaciente(int pacienteId, int leitoId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/check-in');
    
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'leitoId': leitoId,
      }),
    );

    // Erro 409 (Conflito: Leito ocupado ou Paciente já internado)
    if (response.statusCode == 409) {
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'Conflito de Check-in.');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao realizar o check-in. Status: ${response.statusCode}');
    }
  }
  // PATCH /pacientes/:id/check-out
  Future<void> checkOutPaciente(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/check-out');
    
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      throw Exception('Paciente não encontrado em nenhum leito ocupado.');
    }
    if (response.statusCode != 200) {
      throw Exception('Falha ao realizar o check-out. Status: ${response.statusCode}');
    }
  }
}