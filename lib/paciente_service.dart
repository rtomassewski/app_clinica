// lib/paciente_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

// --- MODELOS DE DADOS ---

enum RatingComportamento {
  OTIMO,
  BOM,
  RUIM,
  PESSIMO
}

class NotaComportamento {
  final int id;
  final DateTime dataRegistro;
  final RatingComportamento nota;
  final String? observacao;
  final String nomeProfissional;

  NotaComportamento({
    required this.id,
    required this.dataRegistro,
    required this.nota,
    this.observacao,
    required this.nomeProfissional,
  });

  static RatingComportamento _parseRating(String? ratingStr) {
    switch (ratingStr) {
      case 'OTIMO':
        return RatingComportamento.OTIMO;
      case 'BOM':
        return RatingComportamento.BOM;
      case 'RUIM':
        return RatingComportamento.RUIM;
      case 'PESSIMO':
        return RatingComportamento.PESSIMO;
      default:
        // Lidar com um caso inesperado, embora a API deva garantir isso
        return RatingComportamento.BOM; 
    }
  }

  factory NotaComportamento.fromJson(Map<String, dynamic> json) {
    return NotaComportamento(
      id: json['id'],
      dataRegistro: DateTime.parse(json['data_registro']),
      nota: _parseRating(json['nota']),
      observacao: json['observacao'],
      nomeProfissional: json['usuario_registrou']['nome_completo'],
    );
  }
}

enum StatusPaciente {
  ATIVO,
  ALTA,
  EVADIDO
}

class Paciente {
  final int id;
  final String nomeCompleto;
  final String? nomeSocial;
  final String status;
  final double saldo;
  Paciente({ required this.id, required this.nomeCompleto, this.nomeSocial, required this.status, required this.saldo, });
  factory Paciente.fromJson(Map<String, dynamic> json) {
    final num saldoApi = json['saldo'] as num? ?? 0.0;
    return Paciente(
      id: json['id'],
      nomeCompleto: json['nome_completo'],
      nomeSocial: json['nome_social'],
      status: json['status'],
      saldo: saldoApi.toDouble(),
    );
  }
}

class PacienteDetalhado {
  final int id;
  final String nomeCompleto;
  final String? nomeSocial;
  final String cpf;
  
  final String nomeResponsavel;
  final String telefoneResponsavel;
  final DateTime dataNascimento;
  final DateTime dataAdmissao;
  final String status;
  PacienteDetalhado({ required this.id, required this.nomeCompleto, this.nomeSocial, required this.cpf, required this.nomeResponsavel, required this.telefoneResponsavel, required this.dataNascimento, required this.dataAdmissao, required this.status });
  factory PacienteDetalhado.fromJson(Map<String, dynamic> json) {
    return PacienteDetalhado(
      id: json['id'],
      nomeCompleto: json['nome_completo'],
      nomeSocial: json['nome_social'],
      cpf: json['cpf'],
      nomeResponsavel: json['nome_responsavel'],
      telefoneResponsavel: json['telefone_responsavel'],
      dataNascimento: DateTime.parse(json['data_nascimento']),
      dataAdmissao: DateTime.parse(json['data_admissao']),
      status: json['status'],
    );
  }
}

class Evolucao {
  final int id;
  final String descricao;
  final DateTime dataEvolucao;
  final String nomeProfissional;
  final String papelProfissional;
  Evolucao({ required this.id, required this.descricao, required this.dataEvolucao, required this.nomeProfissional, required this.papelProfissional });
  factory Evolucao.fromJson(Map<String, dynamic> json) {
    return Evolucao(
      id: json['id'],
      descricao: json['descricao'],
      dataEvolucao: DateTime.parse(json['data_evolucao']),
      nomeProfissional: json['usuario']['nome_completo'],
      papelProfissional: json['usuario']['papel']['nome'],
    );
  }
}

// (Modelo de Prescrição CORRIGIDO)
class Prescricao {
  final int id;
  final String medicamentoNome; // Nome do Produto
  final String? dosagem;
  final String posologia;
  final DateTime dataPrescricao;
  final String nomeMedico;
  Prescricao({ required this.id, required this.medicamentoNome, this.dosagem, required this.posologia, required this.dataPrescricao, required this.nomeMedico });
  
  factory Prescricao.fromJson(Map<String, dynamic> json) {
    return Prescricao(
      id: json['id'],
      medicamentoNome: json['produto']['nome'] ?? 'Erro de Dados',
      dosagem: json['dosagem'],
      posologia: json['posologia'],
      dataPrescricao: DateTime.parse(json['data_prescricao']),
      nomeMedico: json['usuario']['nome_completo'],
    );
  }
}

// (Modelo de SinalVital - já existe)
class SinalVital {
  // ... (código existente, não precisa mudar)
  final int id;
  final DateTime dataAfericao;
  final String? pressaoArterial;
  final int? freqCardiaca;
  final int? freqRespiratoria;
  final double? temperatura;
  final int? saturacaoOxigenio;
  final int? glicemia;
  final int? dor;
  final String nomeProfissional;
  SinalVital({ required this.id, required this.dataAfericao, required this.nomeProfissional, this.pressaoArterial, this.freqCardiaca, this.freqRespiratoria, this.temperatura, this.saturacaoOxigenio, this.glicemia, this.dor });
  factory SinalVital.fromJson(Map<String, dynamic> json) {
    return SinalVital(
      id: json['id'],
      dataAfericao: DateTime.parse(json['data_hora_afericao']),
      nomeProfissional: json['usuario_aferiu']['nome_completo'],
      pressaoArterial: json['pressao_arterial'],
      freqCardiaca: json['frequencia_cardiaca'],
      freqRespiratoria: json['frequencia_respiratoria'],
      temperatura: json['temperatura']?.toDouble(),
      saturacaoOxigenio: json['saturacao_oxigenio'],
      glicemia: json['glicemia'],
      dor: json['dor'],
    );
  }
}
class HistoricoMedico {
  final int id;
  final String tipo; // GERAL, PSICOLOGICA, TERAPEUTICA
  final String nomeProfissional;
  final DateTime dataPreenchimento;

  // Campos de texto
  final String? alergias;
  final String? condicoesPrevias;
  final String? medicamentosUsoContinuo;
  final String? historicoFamiliar;
  final String? historicoSocial;
  final String? historicoUsoSubstancias;

  HistoricoMedico({
    required this.id,
    required this.tipo,
    required this.nomeProfissional,
    required this.dataPreenchimento,
    this.alergias,
    this.condicoesPrevias,
    this.medicamentosUsoContinuo,
    this.historicoFamiliar,
    this.historicoSocial,
    this.historicoUsoSubstancias,
  });

  factory HistoricoMedico.fromJson(Map<String, dynamic> json) {
    return HistoricoMedico(
      id: json['id'],
      tipo: json['tipo'],
      nomeProfissional: json['usuario_preencheu']['nome_completo'],
      dataPreenchimento: DateTime.parse(json['data_preenchimento']),
      alergias: json['alergias'],
      condicoesPrevias: json['condicoes_previas'],
      medicamentosUsoContinuo: json['medicamentos_uso_continuo'],
      historicoFamiliar: json['historico_familiar'],
      historicoSocial: json['historico_social'],
      historicoUsoSubstancias: json['historico_uso_substancias'],
    );
  }
}

// (Modelo de Produto - NOVO, para o dropdown)
class Produto {
  final int id;
  final String nome;
  final String unidade;
  Produto({required this.id, required this.nome, required this.unidade});
  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'],
      nome: json['nome'],
      unidade: json['unidade_medida'],
    );
  }
}

// (Modelos de Agendamento e Profissional - já existem)
class Agendamento {
  // ... (código existente)
  final int id;
  final String nomePaciente;
  final String nomeProfissional;
  final DateTime dataHoraInicio;
  Agendamento({ required this.id, required this.nomePaciente, required this.nomeProfissional, required this.dataHoraInicio });
  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      id: json['id'],
      nomePaciente: json['paciente']['nome_completo'],
      nomeProfissional: json['usuario']['nome_completo'],
      dataHoraInicio: DateTime.parse(json['data_hora_inicio']),
    );
  }
}

class Profissional {
  final int id;
  final String nomeCompleto;
  final String? papel; // <--- TEM QUE TER ESTE CAMPO

  Profissional({required this.id, required this.nomeCompleto, this.papel});

  factory Profissional.fromJson(Map<String, dynamic> json) {
    return Profissional(
      id: json['id'],
      nomeCompleto: json['nome_completo'] ?? 'Sem Nome',
      // Mapeia o papel vindo do JSON (pode vir como string direta ou objeto {nome: ...})
      papel: json['papel'] is Map ? json['papel']['nome'] : json['papel'], 
    );
  }
}

// --- CLASSE DO SERVIÇO ---

class PacienteService {
  final AuthService _authService;
  PacienteService(this._authService);

  // --- MÉTODOS DE PACIENTE ---
  // (getPacientes, getPacienteDetalhes, addPaciente)
  // ... (código existente)
  Future<List<Paciente>> getPacientes() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Usuário não autenticado.');
    final url = Uri.parse('$baseUrl/pacientes');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Paciente.fromJson(json)).toList();
      } else { throw Exception('Falha ao carregar pacientes da API.'); }
    } catch (e) { throw Exception('Erro de conexão: $e'); }
  }
  Future<PacienteDetalhado> getPacienteDetalhes(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Usuário não autenticado.');
    final url = Uri.parse('$baseUrl/pacientes/$pacienteId'); 
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        return PacienteDetalhado.fromJson(json.decode(response.body));
      } else { throw Exception('Falha ao carregar detalhes do paciente.'); }
    } catch (e) { throw Exception('Erro de conexão: $e'); }
  }
  Future<void> addPaciente({ required String nomeCompleto, String? nomeSocial, required String cpf, required String dataNascimento, required String nomeResponsavel, required String telefoneResponsavel }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final url = Uri.parse('$baseUrl/pacientes');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: json.encode({'nome_completo': nomeCompleto, 'nome_social': nomeSocial, 'cpf': cpf, 'data_nascimento': dataNascimento, 'nome_responsavel': nomeResponsavel, 'telefone_responsavel': telefoneResponsavel}));
      if (response.statusCode == 409) { throw Exception('Este CPF já está cadastrado.'); }
      if (response.statusCode != 201) { throw Exception('Falha ao salvar o paciente. Status: ${response.statusCode}'); }
    } catch (e) { throw Exception('Erro ao criar paciente: $e'); }
  }

  // --- MÉTODOS DE EVOLUÇÃO ---
  // (getEvolucoes, addEvolucao)
  // ... (código existente)
  Future<List<Evolucao>> getEvolucoes(int pacienteId) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/evolucoes');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Evolucao.fromJson(json)).toList();
    } else { throw Exception('Falha ao carregar evoluções.'); }
  }
  Future<void> addEvolucao(int pacienteId, String descricao) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Usuário não autenticado.');
    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/evolucoes');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: json.encode({'descricao': descricao}));
      if (response.statusCode != 201) { throw Exception('Falha ao salvar a evolução. Status: ${response.statusCode}'); }
    } catch (e) { throw Exception('Erro de conexão ao salvar evolução: $e'); }
  }

  // --- MÉTODOS DE PRESCRIÇÃO (CORRIGIDOS) ---
  Future<List<Prescricao>> getPrescricoes(int pacienteId) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/prescricoes');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Prescricao.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar prescrições.');
    }
  }

  // (addPrescricao CORRIGIDO para o DTO do Back-end)
  Future<void> addPrescricao({
    required int pacienteId,
    required int produtoId,
    required int quantidade,
    String? dosagem,
    required String posologia,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/prescricoes');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'produtoId': produtoId,
          'quantidade_por_dose': quantidade,
          'dosagem': dosagem,
          'posologia': posologia,
        }),
      );

      if (response.statusCode == 201) return;
      if (response.statusCode == 403) { throw Exception('Acesso negado. Somente médicos podem criar prescrições.'); }
      throw Exception('Falha ao salvar a prescrição. Status: ${response.statusCode}');
      
    } catch (e) {
      throw Exception('Erro de conexão ao salvar prescrição: $e');
    }
  }

  // --- MÉTODOS DE SINAIS VITAIS ---
  // (getSinaisVitais, addSinalVital)
  // ... (código existente)
  Future<List<SinalVital>> getSinaisVitais(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final url = Uri.parse('$baseUrl/sinais-vitais').replace(queryParameters: {'pacienteId': pacienteId.toString()});
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => SinalVital.fromJson(json)).toList();
    } else { throw Exception('Falha ao carregar Sinais Vitais.'); }
  }
  Future<void> addSinalVital(int pacienteId, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final url = Uri.parse('$baseUrl/sinais-vitais');
    data['pacienteId'] = pacienteId;
    final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
      body: json.encode(data));
    if (response.statusCode != 201) { throw Exception('Falha ao salvar Sinais Vitais. Status: ${response.statusCode}'); }
  }
  // GET /pacientes/:id/historico
  Future<List<HistoricoMedico>> getHistorico(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/historico');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => HistoricoMedico.fromJson(json)).toList();
    }
    // Se 404 (Nenhum histórico), retorna lista vazia
    if (response.statusCode == 404) {
      return [];
    }
    
    throw Exception('Falha ao carregar o histórico.');
  }

  // POST /pacientes/:id/historico
  Future<void> addHistorico(int pacienteId, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId/historico');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 409) { // Conflito (já existe)
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'Este histórico já existe.');
    }
    if (response.statusCode != 201) {
      throw Exception('Falha ao salvar o histórico. Status: ${response.statusCode}');
    }
  }

  // PATCH /pacientes/:id/historico/:historicoId
  Future<void> updateHistorico(int historicoId, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    
    // (A rota do back-end é aninhada, mas só precisamos do historicoId)
    final url = Uri.parse('$baseUrl/pacientes/0/historico/$historicoId');
    
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o histórico. Status: ${response.statusCode}');
    }
  }

  
  // --- MÉTODOS DE AGENDA/GESTÃO (MOVENDO PARA OS SERVICES CORRETOS) ---
  
  // (getAgendamentos, addAgendamento - Serão movidos para 'agenda_service.dart' depois)
  Future<List<Agendamento>> getAgendamentos(DateTime dataInicio, DateTime dataFim) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final params = {'data_inicio': dataInicio.toIso8601String(), 'data_fim': dataFim.toIso8601String()};
    final url = Uri.parse('$baseUrl/agendamentos').replace(queryParameters: params);
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Agendamento.fromJson(json)).toList();
    } else { throw Exception('Falha ao carregar agendamentos.'); }
  }
  Future<void> addAgendamento({ required int pacienteId, required int usuarioId, required DateTime dataHoraInicio, required DateTime dataHoraFim, String? notas }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final url = Uri.parse('$baseUrl/agendamentos');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: json.encode({'pacienteId': pacienteId, 'usuarioId': usuarioId, 'data_hora_inicio': dataHoraInicio.toIso8601String(), 'data_hora_fim': dataHoraFim.toIso8601String(), 'notas': notas}));
      if (response.statusCode == 409) { throw Exception(json.decode(response.body)['message'] ?? 'Conflito de horário.'); }
      if (response.statusCode == 400) { throw Exception(json.decode(response.body)['message'] ?? 'Dados inválidos.'); }
      if (response.statusCode != 201) { throw Exception('Falha ao salvar agendamento. Status: ${response.statusCode}'); }
    } catch (e) { throw Exception('Erro ao criar agendamento: $e'); }
  }
  
  // (getProfissionais - Será movido para 'gestao_service.dart' depois)
  Future<List<Profissional>> getProfissionais() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');
    final url = Uri.parse('$baseUrl/usuarios');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Profissional.fromJson(json)).toList();
    } else { throw Exception('Falha ao carregar profissionais.'); }
  }

  // --- NOVO MÉTODO: GET /produtos (Para o dropdown de prescrição) ---
  Future<List<Produto>> getProdutos() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/produtos');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Produto.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar produtos do estoque.');
    }
  }
  // PATCH /pacientes/:id
  Future<void> updatePaciente(int pacienteId, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId');
    
    try {
      final response = await http.patch( // Método PATCH
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data), // Envia apenas os campos alterados
      );

      // 409 Conflict (CPF Duplicado)
      if (response.statusCode == 409) {
        throw Exception('Este CPF já está em uso por outro paciente.');
      }
      
      if (response.statusCode != 200) { // 200 OK é o sucesso do PATCH
        throw Exception('Falha ao atualizar o paciente. Status: ${response.statusCode}');
      }
      
    } catch (e) {
      throw Exception('Erro ao atualizar paciente: $e');
    }
    // PATCH /pacientes/:id (Apenas para Status)
  Future<void> updatePacienteStatus({
    required int pacienteId,
    required StatusPaciente status,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/pacientes/$pacienteId');
    
    final response = await http.patch( // Método PATCH
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'status': status.name, // Envia "ATIVO", "ALTA" ou "EVADIDO"
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o status do paciente.');
    }
  }
  }
  // GET /notas-comportamento?pacienteId=:id
  Future<List<NotaComportamento>> getNotasComportamento(int pacienteId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/notas-comportamento').replace(
      queryParameters: {'pacienteId': pacienteId.toString()},
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => NotaComportamento.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar Notas de Comportamento.');
    }
  }

  // POST /notas-comportamento
  Future<void> addNotaComportamento({
    required int pacienteId,
    required RatingComportamento nota,
    String? observacao,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Não autenticado');

    final url = Uri.parse('$baseUrl/notas-comportamento');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'pacienteId': pacienteId,
        'nota': nota.name, // Envia "OTIMO", "BOM", etc.
        'observacao': observacao,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao salvar a nota. Status: ${response.statusCode}');
    }
  }
} // <-- FIM DA CLASSE PacienteService