// lib/paciente_detalhe_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'paciente_service.dart';
import 'package:intl/intl.dart';
import 'paciente_edit_screen.dart';
import 'auth_service.dart';

// --- IMPORTS PARA A GERAÇÃO DE PDF (CORRIGIDOS) ---
import 'impressoes_service.dart'; // O nosso serviço
import 'package:flutter/foundation.dart' show kIsWeb; // Para detetar a Web

// Imports Nativos (Android/iOS)
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

// Imports da Web (Chrome)
//import 'dart:html' as html;
// --- FIM DOS IMPORTS ---


class PacienteDetalheScreen extends StatelessWidget {
  final int pacienteId;
  final String pacienteNome;

  const PacienteDetalheScreen({
    Key? key,
    required this.pacienteId,
    required this.pacienteNome,
  }) : super(key: key);

  // --- FUNÇÃO _gerarPdf (TOTALMENTE REESCRITA) ---
  Future<void> _gerarPdf(BuildContext context) async {
    // 1. Mostrar 'loading'
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = Provider.of<ImpressoesService>(context, listen: false);
      
      // 2. Chamar a API
      final pdfBytes = await service.gerarProntuarioPdf(pacienteId);

      Navigator.of(context).pop(); // Fechar o 'loading'

      // 3. Lógica de Plataforma (APENAS NATIVO/ANDROID)
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/prontuario_$pacienteId.pdf';
      
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Abrir o ficheiro
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Não foi possível abrir o ficheiro: ${result.message}');
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Fechar o 'loading' (se ainda estiver aberto)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(pacienteNome),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimir Prontuário',
              onPressed: () {
                _gerarPdf(context); // Chama a nova lógica
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Informações'),
              Tab(icon: Icon(Icons.history_edu), text: 'Histórico'),
              Tab(icon: Icon(Icons.notes), text: 'Evoluções'),
              Tab(icon: Icon(Icons.medical_services), text: 'Prescrições'),
              Tab(icon: Icon(Icons.monitor_heart), text: 'Sinais Vitais'),
              Tab(icon: Icon(Icons.sentiment_satisfied), text: 'Comportamento'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TabInformacoes(pacienteId: pacienteId),
            _TabHistorico(pacienteId: pacienteId),
            _TabEvolucoes(pacienteId: pacienteId),
            _TabPrescricoes(pacienteId: pacienteId),
            _TabSinaisVitais(pacienteId: pacienteId),
            _TabComportamento(pacienteId: pacienteId),
          ],
        ),
      ),
    );
  }
}

// --- ABA 1: INFORMAÇÕES (SEM MUDANÇAS) ---
class _TabInformacoes extends StatefulWidget {
  final int pacienteId;
  const _TabInformacoes({Key? key, required this.pacienteId}) : super(key: key);
  @override
  State<_TabInformacoes> createState() => _TabInformacoesState();
}
class _TabInformacoesState extends State<_TabInformacoes> {
  PacienteDetalhado? _paciente;
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refreshDetalhes();
  }
  Future<void> _refreshDetalhes() async {
    if (!_isLoading) {
      setState(() { _isLoading = true; _error = null; });
    }
    try {
      final paciente = await Provider.of<PacienteService>(context, listen: false)
          .getPacienteDetalhes(widget.pacienteId);
      setState(() {
        _paciente = paciente;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  Future<void> _navegarParaEditar() async {
    if (_paciente == null) return; 
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PacienteEditScreen(paciente: _paciente!),
      ),
    );
    if (resultado == true) {
      _refreshDetalhes();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: (_paciente == null || _isLoading) 
            ? null
            : _navegarParaEditar,
        child: const Icon(Icons.edit),
        tooltip: 'Editar Paciente',
      ),
    );
  }
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Erro: $_error'));
    }
    if (_paciente == null) {
      return const Center(child: Text('Nenhum dado encontrado.'));
    }
    final paciente = _paciente!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informações Pessoais', style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              _buildInfoRow('Nome Completo:', paciente.nomeCompleto),
              if (paciente.nomeSocial != null)
                _buildInfoRow('Nome Social:', paciente.nomeSocial!),
              _buildInfoRow('CPF:', paciente.cpf),
              _buildInfoRow('Data de Nasc.:', DateFormat('dd/MM/yyyy').format(paciente.dataNascimento.toLocal())),
              _buildInfoRow('Status:', paciente.status),
              const SizedBox(height: 16),
              Text('Responsável', style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              _buildInfoRow('Nome:', paciente.nomeResponsavel),
              _buildInfoRow('Telefone:', paciente.telefoneResponsavel),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

// --- ABA 2: HISTÓRICO ---
class _TabHistorico extends StatefulWidget {
  final int pacienteId;
  const _TabHistorico({Key? key, required this.pacienteId}) : super(key: key);

  @override
  State<_TabHistorico> createState() => _TabHistoricoState();
}
class _TabHistoricoState extends State<_TabHistorico> {
  late Future<List<HistoricoMedico>> _historicoFuture;
  late AuthService _authService;
  HistoricoMedico? _meuHistorico;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _refreshHistorico();
  }

  String _getTipoPorPapel() {
    final papelId = _authService.papelId;
    if (papelId == 3) return 'PSICOLOGICA'; // Psicólogo
    if (papelId == 5) return 'TERAPEUTICA'; // Terapeuta
    return 'GERAL'; // (Médicos, Enfermeiros, etc.)
  }

  void _refreshHistorico() {
    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _meuHistorico = null; 
      
      _historicoFuture = pacienteService.getHistorico(widget.pacienteId);

      _historicoFuture.then((listaDeHistoricos) {
        final meuTipo = _getTipoPorPapel();
        try {
          final historico = listaDeHistoricos.firstWhere((h) => h.tipo == meuTipo);
          setState(() {
            _meuHistorico = historico;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _meuHistorico = null;
            _isLoading = false;
          });
        }
      }).catchError((_) {
        setState(() {
          _meuHistorico = null;
          _isLoading = false;
        });
      });
    });
  }
  
  final _formKey = GlobalKey<FormState>();
  final _alergiasController = TextEditingController();
  final _condicoesController = TextEditingController();
  final _medicamentosController = TextEditingController();
  final _familiarController = TextEditingController();
  final _socialController = TextEditingController();
  final _substanciasController = TextEditingController();
  
  bool _isLoading = true;

  Future<void> _showHistoricoDialog() async {
    bool _isSaving = false;
    
    if (_meuHistorico != null) {
      _alergiasController.text = _meuHistorico!.alergias ?? '';
      _condicoesController.text = _meuHistorico!.condicoesPrevias ?? '';
      _medicamentosController.text = _meuHistorico!.medicamentosUsoContinuo ?? '';
      _familiarController.text = _meuHistorico!.historicoFamiliar ?? '';
      _socialController.text = _meuHistorico!.historicoSocial ?? '';
      _substanciasController.text = _meuHistorico!.historicoUsoSubstancias ?? '';
    } else {
      _alergiasController.clear();
      _condicoesController.clear();
      _medicamentosController.clear();
      _familiarController.clear();
      _socialController.clear();
      _substanciasController.clear();
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(_meuHistorico == null 
                  ? 'Novo Registro de Histórico'
                  : 'Editar Histórico (${_meuHistorico!.tipo})'
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(controller: _alergiasController, decoration: const InputDecoration(labelText: 'Alergias')),
                      TextFormField(controller: _condicoesController, decoration: const InputDecoration(labelText: 'Condições Prévias')),
                      TextFormField(controller: _medicamentosController, decoration: const InputDecoration(labelText: 'Medicamentos (Uso Contínuo)')),
                      TextFormField(controller: _familiarController, decoration: const InputDecoration(labelText: 'Histórico Familiar')),
                      TextFormField(controller: _socialController, decoration: const InputDecoration(labelText: 'Histórico Social')),
                      TextFormField(controller: _substanciasController, decoration: const InputDecoration(labelText: 'Histórico (Uso de Substâncias)')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    setModalState(() => _isSaving = true);
                    
                    final Map<String, dynamic> data = {
                      'alergias': _alergiasController.text.isEmpty ? null : _alergiasController.text,
                      'condicoes_previas': _condicoesController.text.isEmpty ? null : _condicoesController.text,
                      'medicamentos_uso_continuo': _medicamentosController.text.isEmpty ? null : _medicamentosController.text,
                      'historico_familiar': _familiarController.text.isEmpty ? null : _familiarController.text,
                      'historico_social': _socialController.text.isEmpty ? null : _socialController.text,
                      'historico_uso_substancias': _substanciasController.text.isEmpty ? null : _substanciasController.text,
                    };
                    
                    try {
                      final service = Provider.of<PacienteService>(context, listen: false);
                      
                      if (_meuHistorico == null) {
                        await service.addHistorico(widget.pacienteId, data);
                      } else {
                        await service.updateHistorico(_meuHistorico!.id, data);
                      }
                      
                      Navigator.of(context).pop();
                      _refreshHistorico();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                      );
                    } finally {
                      setModalState(() => _isSaving = false);
                    }
                  },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<HistoricoMedico>>(
        future: _historicoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return const Center(child: Text('Nenhum histórico médico registrado.'));
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum histórico médico registrado.'));
          }

          final historicos = snapshot.data!;
          return ListView.builder(
            itemCount: historicos.length,
            itemBuilder: (context, index) {
              final h = historicos[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico ${h.tipo}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Registrado por: ${h.nomeProfissional} em ${DateFormat('dd/MM/yyyy').format(h.dataPreenchimento.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(),
                      if (h.alergias != null && h.alergias!.isNotEmpty) _buildHistoricoRow('Alergias:', h.alergias!),
                      if (h.condicoesPrevias != null && h.condicoesPrevias!.isNotEmpty) _buildHistoricoRow('Condições Prévias:', h.condicoesPrevias!),
                      if (h.medicamentosUsoContinuo != null && h.medicamentosUsoContinuo!.isNotEmpty) _buildHistoricoRow('Uso Contínuo:', h.medicamentosUsoContinuo!),
                      if (h.historicoFamiliar != null && h.historicoFamiliar!.isNotEmpty) _buildHistoricoRow('Hist. Familiar:', h.historicoFamiliar!),
                      if (h.historicoSocial != null && h.historicoSocial!.isNotEmpty) _buildHistoricoRow('Hist. Social:', h.historicoSocial!),
                      if (h.historicoUsoSubstancias != null && h.historicoUsoSubstancias!.isNotEmpty) _buildHistoricoRow('Uso de Substâncias:', h.historicoUsoSubstancias!),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showHistoricoDialog,
        child: Icon(
          _meuHistorico == null ? Icons.add : Icons.edit
        ),
        tooltip: _meuHistorico == null 
            ? 'Novo Registro de Histórico'
            : 'Editar Meu Histórico',
      ),
    );
  }
  
  Widget _buildHistoricoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

// --- WIDGET DA ABA 3: EVOLUÇÕES ---
class _TabEvolucoes extends StatefulWidget {
  final int pacienteId;
  const _TabEvolucoes({Key? key, required this.pacienteId}) : super(key: key);
  @override
  State<_TabEvolucoes> createState() => _TabEvolucoesState();
}
class _TabEvolucoesState extends State<_TabEvolucoes> {
  late Future<List<Evolucao>> _evolucoesFuture;
  final _evolucaoController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _refreshEvolucoes();
  }
  void _refreshEvolucoes() {
    setState(() {
      _evolucoesFuture = Provider.of<PacienteService>(context, listen: false)
          .getEvolucoes(widget.pacienteId);
    });
  }
  Future<void> _showAddEvolucaoDialog() async {
    _evolucaoController.clear();
    bool isSaving = false;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Nova Evolução'),
              content: SingleChildScrollView(
                child: TextField(
                  controller: _evolucaoController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Paciente relatou melhora...',
                  ),
                  maxLines: 5,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (_evolucaoController.text.isEmpty) {
                      return;
                    }
                    setDialogState(() { isSaving = true; });
                    try {
                      await Provider.of<PacienteService>(context, listen: false)
                          .addEvolucao(
                        widget.pacienteId,
                        _evolucaoController.text,
                      );
                      Navigator.of(context).pop();
                      _refreshEvolucoes();
                    } catch (e) {
                      setDialogState(() { isSaving = false; });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar: $e')),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Evolucao>>(
        future: _evolucoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma evolução encontrada.'));
          }
          final evolucoes = snapshot.data!;
          return ListView.builder(
            itemCount: evolucoes.length,
            itemBuilder: (context, index) {
              final evolucao = evolucoes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(evolucao.descricao),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yy HH:mm').format(evolucao.dataEvolucao.toLocal())}\n'
                    'Por: ${evolucao.nomeProfissional} (${evolucao.papelProfissional})',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEvolucaoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Nova Evolução',
      ),
    );
  }
}

// --- WIDGET DA ABA 4: PRESCRIÇÕES ---
class _TabPrescricoes extends StatefulWidget {
  final int pacienteId;
  const _TabPrescricoes({Key? key, required this.pacienteId}) : super(key: key);

  @override
  State<_TabPrescricoes> createState() => _TabPrescricoesState();
}
class _TabPrescricoesState extends State<_TabPrescricoes> {
  late Future<List<Prescricao>> _prescricoesFuture;
  late Future<List<Produto>> _produtosFuture;
  final _dosagemController = TextEditingController();
  final _posologiaController = TextEditingController();
  final _quantidadeController = TextEditingController(text: '1');
  Produto? _produtoSelecionado;

  @override
  void initState() {
    super.initState();
    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    _prescricoesFuture = pacienteService.getPrescricoes(widget.pacienteId);
    _produtosFuture = pacienteService.getProdutos();
  }

  void _refreshPrescricoes() {
    setState(() {
      _prescricoesFuture = Provider.of<PacienteService>(context, listen: false)
          .getPrescricoes(widget.pacienteId);
    });
  }

  Future<void> _showAddPrescricaoDialog(List<Produto> produtos) async {
    final _formKey = GlobalKey<FormState>();
    _dosagemController.clear();
    _posologiaController.clear();
    _quantidadeController.text = '1';
    _produtoSelecionado = null;
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Adicionar Nova Prescrição'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Produto>(
                        value: _produtoSelecionado,
                        hint: const Text('Selecione um Medicamento*'),
                        isExpanded: true,
                        items: produtos.map((produto) {
                          return DropdownMenuItem(
                            value: produto,
                            child: Text(produto.nome, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => _produtoSelecionado = value);
                        },
                        validator: (value) => value == null ? 'Obrigatório' : null,
                      ),
                      TextFormField(
                        controller: _quantidadeController,
                        decoration: const InputDecoration(labelText: 'Quantidade por dose*'),
                        keyboardType: TextInputType.number,
                        validator: (value) => (int.tryParse(value ?? '0') ?? 0) <= 0
                            ? 'Deve ser > 0'
                            : null,
                      ),
                      TextFormField(
                        controller: _dosagemController,
                        decoration: const InputDecoration(labelText: 'Dosagem (Opcional, ex: 50mg)'),
                      ),
                      TextFormField(
                        controller: _posologiaController,
                        decoration: const InputDecoration(labelText: 'Posologia (Instruções)*'),
                        validator: (value) =>
                            value!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            try {
                              await Provider.of<PacienteService>(context, listen: false)
                                  .addPrescricao(
                                pacienteId: widget.pacienteId,
                                produtoId: _produtoSelecionado!.id,
                                quantidade: int.parse(_quantidadeController.text),
                                dosagem: _dosagemController.text.isEmpty
                                    ? null
                                    : _dosagemController.text,
                                posologia: _posologiaController.text,
                              );
                              Navigator.of(context).pop();
                              _refreshPrescricoes();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                              );
                            } finally {
                              setModalState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Prescricao>>(
        future: _prescricoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma prescrição encontrada.'));
          }

          final prescricoes = snapshot.data!;
          return ListView.builder(
            itemCount: prescricoes.length,
            itemBuilder: (context, index) {
              final prescricao = prescricoes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    (prescricao.dosagem != null && prescricao.dosagem!.isNotEmpty)
                      ? '${prescricao.medicamentoNome} (${prescricao.dosagem})'
                      : prescricao.medicamentoNome,
                  ),
                  subtitle: Text(
                    '${prescricao.posologia}\n'
                    'Dr(a): ${prescricao.nomeMedico} - ${DateFormat('dd/MM/yy').format(prescricao.dataPrescricao.toLocal())}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final produtos = await _produtosFuture;
            _showAddPrescricaoDialog(produtos);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar produtos: $e'), backgroundColor: Colors.red),
            );
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Nova Prescrição',
      ),
    );
  }
}

// --- WIDGET DA ABA 5: SINAIS VITAIS ---
class _TabSinaisVitais extends StatefulWidget {
  final int pacienteId;
  const _TabSinaisVitais({Key? key, required this.pacienteId}) : super(key: key);
  @override
  State<_TabSinaisVitais> createState() => _TabSinaisVitaisState();
}
class _TabSinaisVitaisState extends State<_TabSinaisVitais> {
  late Future<List<SinalVital>> _sinaisFuture;

  @override
  void initState() {
    super.initState();
    _refreshSinaisVitais();
  }

  void _refreshSinaisVitais() {
    setState(() {
      _sinaisFuture = Provider.of<PacienteService>(context, listen: false)
          .getSinaisVitais(widget.pacienteId);
    });
  }

  Future<void> _showAddSinalVitalDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _paController = TextEditingController();
    final _fcController = TextEditingController();
    final _frController = TextEditingController();
    final _tempController = TextEditingController();
    final _satController = TextEditingController();
    final _glicemiaController = TextEditingController();
    final _dorController = TextEditingController();
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Registrar Sinais Vitais'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(controller: _paController, decoration: const InputDecoration(labelText: 'Pressão Arterial (ex: 120/80)')),
                      TextFormField(controller: _fcController, decoration: const InputDecoration(labelText: 'Freq. Cardíaca (BPM)'), keyboardType: TextInputType.number),
                      TextFormField(controller: _frController, decoration: const InputDecoration(labelText: 'Freq. Respiratória (RPM)'), keyboardType: TextInputType.number),
                      TextFormField(controller: _tempController, decoration: const InputDecoration(labelText: 'Temperatura (ex: 36.5)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      TextFormField(controller: _satController, decoration: const InputDecoration(labelText: 'Saturação O2 (%)'), keyboardType: TextInputType.number),
                      TextFormField(controller: _glicemiaController, decoration: const InputDecoration(labelText: 'Glicemia (mg/dL)'), keyboardType: TextInputType.number),
                      TextFormField(controller: _dorController, decoration: const InputDecoration(labelText: 'Dor (0-10)'), keyboardType: TextInputType.number),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    setModalState(() => _isSaving = true);
                    
                    final Map<String, dynamic> data = {
                      'pressao_arterial': _paController.text.isEmpty ? null : _paController.text,
                      'frequencia_cardiaca': int.tryParse(_fcController.text),
                      'frequencia_respiratoria': int.tryParse(_frController.text),
                      'temperatura': double.tryParse(_tempController.text),
                      'saturacao_oxigenio': int.tryParse(_satController.text),
                      'glicemia': int.tryParse(_glicemiaController.text),
                      'dor': int.tryParse(_dorController.text),
                    };
                    
                    try {
                      await Provider.of<PacienteService>(context, listen: false)
                          .addSinalVital(widget.pacienteId, data);
                      
                      Navigator.of(context).pop();
                      _refreshSinaisVitais();

                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                      );
                    } finally {
                      setModalState(() => _isSaving = false);
                    }
                  },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<SinalVital>>(
        future: _sinaisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum sinal vital registrado.'));
          }

          final sinais = snapshot.data!;
          return ListView.builder(
            itemCount: sinais.length,
            itemBuilder: (context, index) {
              final sinal = sinais[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    'PA: ${sinal.pressaoArterial ?? '--'} | FC: ${sinal.freqCardiaca ?? '--'} | Temp: ${sinal.temperatura ?? '--'}°C',
                  ),
                  subtitle: Text(
                    'SPO2: ${sinal.saturacaoOxigenio ?? '--'}% | Dor: ${sinal.dor ?? '--'} | Por: ${sinal.nomeProfissional}\n'
                    '${DateFormat('dd/MM/yy HH:mm').format(sinal.dataAfericao.toLocal())}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSinalVitalDialog,
        child: const Icon(Icons.add),
        tooltip: 'Registrar Sinais',
      ),
    );
  }
}

// --- WIDGET DA ABA 6: COMPORTAMENTO (NOVO) ---
class _TabComportamento extends StatefulWidget {
  final int pacienteId;
  const _TabComportamento({Key? key, required this.pacienteId}) : super(key: key);

  @override
  State<_TabComportamento> createState() => _TabComportamentoState();
}

class _TabComportamentoState extends State<_TabComportamento> {
  late Future<List<NotaComportamento>> _notasFuture;
  late AuthService _authService; // Para checar permissão

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _refreshNotas();
  }

  void _refreshNotas() {
    setState(() {
      _notasFuture = Provider.of<PacienteService>(context, listen: false)
          .getNotasComportamento(widget.pacienteId);
    });
  }

  // O Modal de Adicionar
  Future<void> _showAddNotaDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _obsController = TextEditingController();
    RatingComportamento? _notaSelecionada;
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Nova Nota de Comportamento'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<RatingComportamento>(
                        value: _notaSelecionada,
                        hint: const Text('Selecione a Nota*'),
                        items: const [
                          DropdownMenuItem(value: RatingComportamento.OTIMO, child: Text('Ótimo')),
                          DropdownMenuItem(value: RatingComportamento.BOM, child: Text('Bom')),
                          DropdownMenuItem(value: RatingComportamento.RUIM, child: Text('Ruim')),
                          DropdownMenuItem(value: RatingComportamento.PESSIMO, child: Text('Péssimo')),
                        ],
                        onChanged: (v) => setModalState(() => _notaSelecionada = v),
                        validator: (v) => v == null ? 'Obrigatório' : null,
                      ),
                      TextFormField(
                        controller: _obsController,
                        decoration: const InputDecoration(labelText: 'Observação'),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSaving || _notaSelecionada == null
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            try {
                              await Provider.of<PacienteService>(context, listen: false)
                                  .addNotaComportamento(
                                pacienteId: widget.pacienteId,
                                nota: _notaSelecionada!,
                                observacao: _obsController.text.isEmpty ? null : _obsController.text,
                              );
                              Navigator.of(context).pop();
                              _refreshNotas();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                              );
                            } finally {
                              setModalState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Color _getNotaColor(RatingComportamento nota) {
    switch (nota) {
      case RatingComportamento.OTIMO:
        return Colors.green;
      case RatingComportamento.BOM:
        return Colors.blue;
      case RatingComportamento.RUIM:
        return Colors.orange;
      case RatingComportamento.PESSIMO:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<NotaComportamento>>(
        future: _notasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Se o 404 da API (nenhuma nota) vier, o 'catchError' no refresh
            // pode não ter sido pego, então tratamos como lista vazia.
            return const Center(child: Text('Nenhuma nota de comportamento registrada.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma nota de comportamento registrada.'));
          }

          final notas = snapshot.data!;
          return ListView.builder(
            itemCount: notas.length,
            itemBuilder: (context, index) {
              final nota = notas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.sentiment_very_satisfied, // (Pode mudar o ícone)
                    color: _getNotaColor(nota.nota),
                  ),
                  title: Text(
                    nota.nota.name, // "OTIMO", "BOM", etc.
                    style: TextStyle(color: _getNotaColor(nota.nota), fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${nota.observacao ?? "Sem observações."}\n'
                    'Por: ${nota.nomeProfissional} - ${DateFormat('dd/MM/yy HH:mm').format(nota.dataRegistro.toLocal())}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (_authService.isGestor)
          ? FloatingActionButton(
              onPressed: _showAddNotaDialog,
              child: const Icon(Icons.add),
              tooltip: 'Nova Nota',
            )
          : null,
    );
  }
  void _showAdicionarCreditoDialog(BuildContext context, int pacienteId) {
  final valorCtrl = TextEditingController();
  
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Adicionar Crédito"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Este valor entrará no caixa como RECEITA e ficará disponível para o paciente gastar na loja."),
          const SizedBox(height: 10),
          TextField(
            controller: valorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Valor (R\$)", prefixText: "R\$ "),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () async {
            // Chamar API: LojaService.adicionarCredito(pacienteId, valor)
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Crédito adicionado!")));
          },
          child: const Text("CONFIRMAR"),
        )
      ],
    )
  );
}
}