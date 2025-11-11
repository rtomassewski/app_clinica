// lib/enfermagem_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'enfermagem_service.dart';
import 'auth_service.dart';
import 'paciente_service.dart'; // Para os modelos Paciente/Prescricao

class EnfermagemScreen extends StatefulWidget {
  const EnfermagemScreen({Key? key}) : super(key: key);

  @override
  State<EnfermagemScreen> createState() => _EnfermagemScreenState();
}

class _EnfermagemScreenState extends State<EnfermagemScreen> {
  late Future<List<AdministracaoPendente>> _pendentesFuture;
  late AuthService _authService;
  late EnfermagemService _enfermagemService; // Para o modal

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _enfermagemService = Provider.of<EnfermagemService>(context, listen: false);
    _refreshLista();
  }

  void _refreshLista() {
    setState(() {
      _pendentesFuture = _enfermagemService.getAdministracoesPendentes();
    });
  }

  // (Modal de "Dar Baixa" - _showAdministrarDialog - não muda)
  Future<void> _showAdministrarDialog(AdministracaoPendente tarefa) async {
    final _formKey = GlobalKey<FormState>(); // Chave do formulário
    final _notasController = TextEditingController();
    StatusAdministracao? _statusSelecionado;
    bool _isSaving = false;
    final _quantidadeController =
        TextEditingController(text: tarefa.quantidade.toString());

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(tarefa.produtoNome),
              content: Form( // Adicionado Form
                key: _formKey, // Adicionado FormKey
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paciente: ${tarefa.pacienteNome}'),
                      Text(
                          'Horário Previsto: ${DateFormat('HH:mm').format(tarefa.dataHoraPrevista.toLocal())}'),
                      const Divider(height: 24),
                      Text('Confirmar Ação:',
                          style: Theme.of(context).textTheme.titleSmall),
                      DropdownButtonFormField<StatusAdministracao>(
                        value: _statusSelecionado,
                        hint: const Text('Selecione um status*'),
                        items: const [
                          DropdownMenuItem(
                              value: StatusAdministracao.ADMINISTRADO,
                              child: Text('✅ Administrado')),
                          DropdownMenuItem(
                              value: StatusAdministracao.RECUSADO,
                              child: Text('❌ Recusado pelo Paciente')),
                          DropdownMenuItem(
                              value: StatusAdministracao.NAO_ADMINISTRADO,
                              child: Text('⚠️ Não Administrado')),
                        ],
                        onChanged: (value) {
                          setModalState(() => _statusSelecionado = value);
                        },
                        validator: (v) => v == null ? 'Obrigatório' : null,
                      ),
                      if (_statusSelecionado ==
                          StatusAdministracao.ADMINISTRADO)
                        TextFormField(
                          controller: _quantidadeController,
                          decoration: const InputDecoration(
                              labelText: 'Quantidade Administrada*'),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (int.tryParse(v ?? '0') ?? 0) <= 0 ? 'Inválido' : null,
                        ),
                      if (_statusSelecionado == StatusAdministracao.RECUSADO ||
                          _statusSelecionado ==
                              StatusAdministracao.NAO_ADMINISTRADO)
                        TextFormField(
                          controller: _notasController,
                          decoration:
                              const InputDecoration(labelText: 'Notas (Obrigatório)*'),
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isSaving || _statusSelecionado == null
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) { // Validando o Form
                            setModalState(() => _isSaving = true);
                            try {
                              await _enfermagemService.administrarMedicamento(
                                id: tarefa.id,
                                status: _statusSelecionado!,
                                quantidade:
                                    int.tryParse(_quantidadeController.text),
                                notas: _notasController.text.isEmpty
                                    ? null
                                    : _notasController.text,
                              );
                              Navigator.of(context).pop();
                              _refreshLista();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Erro: $e'),
                                    backgroundColor: Colors.red),
                              );
                            } finally {
                              setModalState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- (CORRIGIDO) MODAL DE APRAZAMENTO (CRIAR TAREFA) ---
  Future<void> _showAprazamentoDialog() async {
    // Controladores do formulário
    final _formKey = GlobalKey<FormState>();
    final _notasController = TextEditingController();
    Paciente? _pacienteSelecionado;
    Prescricao? _prescricaoSelecionada;
    DateTime _dataHoraPrevista = DateTime.now();

    // Dados para os dropdowns (buscados da API)
    List<Paciente> _pacientes = [];
    List<Prescricao> _prescricoes = [];
    String? _erroLoading;
    bool _isLoadingDados = true;
    
    // --- CORREÇÃO 1: Declarar a variável AQUI ---
    bool _isLoadingPrescricoes = false;

    // Busca os dados para os dropdowns
    Future<void> _loadModalData() async {
      try {
        _pacientes = await _enfermagemService.getPacientes();
      } catch (e) {
        _erroLoading = e.toString();
      }
    }

    // Busca as prescrições DEPOIS que um paciente é selecionado
    Future<void> _loadPrescricoes(int pacienteId, Function(VoidCallback) setModalState) async {
      setModalState(() {
        _isLoadingPrescricoes = true; // <-- Agora esta linha é válida
        _prescricaoSelecionada = null; 
        _prescricoes = []; 
      });
      try {
        _prescricoes = await _enfermagemService.getPrescricoes(pacienteId);
      } catch (e) {
        // Tratar erro
      }
      setModalState(() {
        _isLoadingPrescricoes = false; // <-- Esta linha também é válida
      });
    }

    // Helper para selecionar Data/Hora
    Future<void> _selecionarDataHora(BuildContext context, Function(VoidCallback) setModalState) async {
      final DateTime? pickedDate = await showDatePicker(
          context: context, initialDate: _dataHoraPrevista, firstDate: DateTime.now(), lastDate: DateTime(2100));
      if (pickedDate == null) return;
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dataHoraPrevista));
      if (pickedTime == null) return;
      
      setModalState(() {
        _dataHoraPrevista = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool _isSaving = false;
        
        // --- CORREÇÃO 2: Remover a declaração daqui ---
        // bool _isLoadingPrescricoes = false; // (Removido)

        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Carrega os dados na primeira vez
            if (_isLoadingDados) {
              _loadModalData().whenComplete(() {
                setModalState(() {
                  _isLoadingDados = false;
                });
              });
            }

            return AlertDialog(
              title: const Text('Agendar Medicação (Aprazar)'),
              content: _isLoadingDados
                  ? const Center(child: CircularProgressIndicator())
                  : _erroLoading != null
                      ? Center(child: Text('Erro: $_erroLoading'))
                      : Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButtonFormField<Paciente>(
                                  value: _pacienteSelecionado,
                                  hint: const Text('Selecione um Paciente*'),
                                  items: _pacientes.map((pac) {
                                    return DropdownMenuItem(value: pac, child: Text(pac.nomeCompleto));
                                  }).toList(),
                                  onChanged: (value) {
                                    setModalState(() => _pacienteSelecionado = value);
                                    if (value != null) {
                                      _loadPrescricoes(value.id, setModalState);
                                    }
                                  },
                                  validator: (v) => v == null ? 'Obrigatório' : null,
                                ),
                                
                                if (_pacienteSelecionado != null)
                                  _isLoadingPrescricoes // <-- Esta linha agora é válida
                                      ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                                      : DropdownButtonFormField<Prescricao>(
                                          value: _prescricaoSelecionada,
                                          hint: const Text('Selecione a Prescrição*'),
                                          isExpanded: true,
                                          items: _prescricoes.map((p) {
                                            return DropdownMenuItem(value: p, child: Text(p.medicamentoNome, overflow: TextOverflow.ellipsis));
                                          }).toList(),
                                          onChanged: (value) => setModalState(() => _prescricaoSelecionada = value),
                                          validator: (v) => v == null ? 'Obrigatório' : null,
                                        ),
                                
                                const SizedBox(height: 16),
                                Text('Data/Hora Prevista: ${DateFormat('dd/MM/yy HH:mm').format(_dataHoraPrevista)}'),
                                ElevatedButton(onPressed: () => _selecionarDataHora(context, setModalState), child: const Text('Mudar Data/Hora')),
                                
                                TextFormField(
                                  controller: _notasController,
                                  decoration: const InputDecoration(labelText: 'Notas (Opcional)'),
                                ),
                              ],
                            ),
                          ),
                        ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSaving || _prescricaoSelecionada == null
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            try {
                              await _enfermagemService.addAprazamento(
                                pacienteId: _pacienteSelecionado!.id,
                                prescricaoId: _prescricaoSelecionada!.id,
                                dataHoraPrevista: _dataHoraPrevista,
                                notas: _notasController.text.isEmpty ? null : _notasController.text,
                              );
                              Navigator.of(context).pop();
                              _refreshLista();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                            } finally {
                              setModalState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Salvar'),
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
      appBar: AppBar(
        title: const Text('Enfermagem - Pendências'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Lista',
            onPressed: _refreshLista,
          ),
        ],
      ),
      body: FutureBuilder<List<AdministracaoPendente>>(
        future: _pendentesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma medicação pendente.'));
          }

          final pendentes = snapshot.data!;
          return ListView.builder(
            itemCount: pendentes.length,
            itemBuilder: (context, index) {
              final tarefa = pendentes[index];
              return Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(DateFormat('HH:mm').format(tarefa.dataHoraPrevista.toLocal())),
                  ),
                  title: Text('${tarefa.produtoNome} (Qtd: ${tarefa.quantidade}) ${tarefa.dosagem ?? ''}'),
                  subtitle: Text('Paciente: ${tarefa.pacienteNome}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAdministrarDialog(tarefa),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _authService.podeAprazar
          ? FloatingActionButton(
              onPressed: _showAprazamentoDialog,
              child: const Icon(Icons.add_task),
              tooltip: 'Novo Aprazamento',
            )
          : null,
    );
  }
}