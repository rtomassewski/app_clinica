// lib/enfermagem_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'paciente_service.dart'; // 1. Importe (para os modelos Paciente/Prescricao)

// (Enum StatusAdministracao - já deve estar aqui)
enum StatusAdministracao {
  PENDENTE,
  ADMINISTRADO,
  RECUSADO,
  NAO_ADMINISTRADO
}

// 1. Modelo de Dados da "Tarefa" de Enfermagem
class AdministracaoPendente {
  final int id; // ID da *administração* (a tarefa)
  final DateTime dataHoraPrevista;
  final String pacienteNome;
  final String produtoNome;
  final String? dosagem;
  final int quantidade; // Quantos (ex: 1, 2)

  AdministracaoPendente({
    required this.id,
    required this.dataHoraPrevista,
    required this.pacienteNome,
    required this.produtoNome,
    this.dosagem,
    required this.quantidade,
  });

  factory AdministracaoPendente.fromJson(Map<String, dynamic> json) {
    final prescricao = json['prescricao'];
    return AdministracaoPendente(
      id: json['id'],
      dataHoraPrevista: DateTime.parse(json['data_hora_prevista']),
      pacienteNome: json['paciente']['nome_completo'],
      produtoNome: prescricao['produto']['nome'],
      dosagem: prescricao['dosagem'],
      quantidade: prescricao['quantidade_por_dose'],
    );
  }
}


class EnfermagemService {
  final AuthService _authService;
  EnfermagemService(this._authService);

  // 2. GET /administracao-medicamentos?status=PENDENTE
  Future<List<AdministracaoPendente>> getAdministracoesPendentes() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/administracao-medicamentos').replace(
      queryParameters: {'status': 'PENDENTE'},
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => AdministracaoPendente.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar lista de enfermagem.');
    }
  }

  // 3. PATCH /administracao-medicamentos/:id/administrar
  Future<void> administrarMedicamento({
    required int id,
    required StatusAdministracao status,
    required int? quantidade,
    String? notas,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/administracao-medicamentos/$id/administrar');
    
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'status': status.name,
        'quantidade_administrada': quantidade,
        'notas': notas,
      }),
    );
    
    if (response.statusCode == 409) {
       final body = json.decode(response.body);
       throw Exception(body['message'] ?? 'Conflito ao administrar.');
    }
    
    if (response.statusCode != 200) {
      throw Exception('Falha ao administrar medicação. Status: ${response.statusCode}');
    }
  }

  // --- 4. MÉTODOS QUE FALTAVAM (A CORREÇÃO) ---

  // POST /administracao-medicamentos (Aprazamento)
  Future<void> addAprazamento({
    required int pacienteId,
    required int prescricaoId,
    required DateTime dataHoraPrevista,
    String? notas,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/administracao-medicamentos');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'pacienteId': pacienteId,
        'prescricaoId': prescricaoId,
        'data_hora_prevista': dataHoraPrevista.toIso8601String(),
        'notas': notas,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar aprazamento. Status: ${response.statusCode}');
    }
  }

  // GET /pacientes (Para o dropdown)
  Future<List<Paciente>> getPacientes() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Paciente.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar pacientes.');
    }
  }

  // GET /pacientes/:id/prescricoes (Para o dropdown dependente)
  Future<List<Prescricao>> getPrescricoes(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/prescricoes');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Prescricao.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar prescrições.');
    }
  }
}