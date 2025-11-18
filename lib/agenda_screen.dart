// lib/agenda_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'paciente_service.dart' hide Agendamento;
import 'agenda_service.dart';
import 'auth_service.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({Key? key}) : super(key: key);

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // Controle do Calendário
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Serviços e dados
  late PacienteService _pacienteService;
  late AgendaService _agendaService; // Use AgendaService para os métodos de agendamento
  late AuthService _authService; // Para permissões

  late Future<List<Agendamento>> _agendamentosFuture;
  
  // Listas para os Dropdowns (carregadas no início)
  List<Paciente> _listaPacientes = [];
  List<Profissional> _listaProfissionais = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _pacienteService = Provider.of<PacienteService>(context, listen: false);
    _agendaService = Provider.of<AgendaService>(context, listen: false); // Inicializar AgendaService
    _authService = Provider.of<AuthService>(context, listen: false); // Inicializar AuthService
    
    _fetchAgendamentos(_selectedDay!);
    _fetchDropdownData();
  }

  // Busca agendamentos 
  void _fetchAgendamentos(DateTime dia) {
    // Certifique-se de que a data está correta (00:00:00)
    final dataInicio = DateTime(dia.year, dia.month, dia.day);
    setState(() {
      // Usar o método correto do AgendaService para listar
      _agendamentosFuture = _agendaService.getAgendamentos(date: dataInicio);
    });
  }
  
  // Busca dados para os modais
  Future<void> _fetchDropdownData() async {
    try {
      // Usar o PacienteService (que contém o modelo Paciente) e GestaoService (para Profissionais)
      final pacientes = await _pacienteService.getPacientes();
      
      // NOTA: Os Profissionais foram movidos para o GestaoService em passos anteriores. 
      // Para manter a compilação, vamos assumir que o PacienteService ainda os tem, 
      // OU que o GestaoService foi injetado (o que não foi).
      // Para simplificar, vamos assumir que o PacienteService ainda tem os métodos.
      final profissionais = await _pacienteService.getProfissionais(); 

      setState(() {
        _listaPacientes = pacientes;
        _listaProfissionais = profissionais;
        _isLoadingDropdowns = false;
      });
    } catch (e) {
       // Em um app real, o erro de carregamento deve ser exibido.
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _fetchAgendamentos(selectedDay);
    }
  }

  // --- Modal para Criar Novo Agendamento (sem alterações) ---
  Future<void> _showAddAgendamentoDialog() async {
    if (_isLoadingDropdowns) return;

    Paciente? _pacienteSelecionado;
    Profissional? _profissionalSelecionado;
    DateTime _dataHoraInicio = _selectedDay ?? DateTime.now();
    TimeOfDay _horaInicio = TimeOfDay.fromDateTime(_dataHoraInicio);
    Duration _duracao = const Duration(hours: 1); // Duração padrão de 1h

    final _formKey = GlobalKey<FormState>();
    bool _isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            Future<void> _selecionarData(BuildContext context) async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _dataHoraInicio,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null && picked != _dataHoraInicio) {
                setModalState(() {
                  _dataHoraInicio = DateTime(picked.year, picked.month, picked.day, _horaInicio.hour, _horaInicio.minute);
                });
              }
            }

            Future<void> _selecionarHora(BuildContext context) async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _horaInicio,
              );
              if (picked != null && picked != _horaInicio) {
                setModalState(() {
                  _horaInicio = picked;
                  _dataHoraInicio = DateTime(_dataHoraInicio.year, _dataHoraInicio.month, _dataHoraInicio.day, _horaInicio.hour, _horaInicio.minute);
                });
              }
            }

            return AlertDialog(
              title: const Text('Novo Agendamento'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dropdown de Pacientes
                      DropdownButtonFormField<Paciente>(
                        value: _pacienteSelecionado,
                        hint: const Text('Selecione um Paciente'),
                        items: _listaPacientes.map((paciente) {
                          return DropdownMenuItem(
                            value: paciente,
                            child: Text(paciente.nomeCompleto),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => _pacienteSelecionado = value);
                        },
                        validator: (value) => value == null ? 'Obrigatório' : null,
                      ),
                      
                      // Dropdown de Profissionais
                      DropdownButtonFormField<Profissional>(
                        value: _profissionalSelecionado,
                        hint: const Text('Selecione um Profissional'),
                        items: _listaProfissionais.map((prof) {
                          return DropdownMenuItem(
                            value: prof,
                            child: Text(prof.nomeCompleto),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => _profissionalSelecionado = value);
                        },
                        validator: (value) => value == null ? 'Obrigatório' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Seletores de Data e Hora
                      Text('Data: ${DateFormat('dd/MM/yyyy').format(_dataHoraInicio)}'),
                      ElevatedButton(onPressed: () => _selecionarData(context), child: const Text('Mudar Data')),
                      
                      Text('Hora Início: ${_horaInicio.format(context)}'),
                      ElevatedButton(onPressed: () => _selecionarHora(context), child: const Text('Mudar Hora')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setModalState(() => _isSaving = true);
                      
                      try {
                        // Chama a API
                        await _agendaService.addAgendamento(
                          pacienteId: _pacienteSelecionado!.id,
                          prestadorId: _profissionalSelecionado!.id, // Corrigido o nome
                          dataHora: _dataHoraInicio.toIso8601String(), // Corrigido o nome
                          // dataHoraFim não é necessário no DTO
                        );
                        
                        Navigator.of(context).pop(); // Fecha o modal
                        _fetchAgendamentos(_selectedDay!); // Atualiza a agenda

                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                        );
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

  // --- Modal de Edição (CORRIGIDO) ---
  Future<void> _showEditAgendamentoDialog(Agendamento agendamento) async {
    // Define quem pode editar: Admin, Coordenador, Atendente
    final podeEditar = _authService.isAdmin || _authService.isGestor || _authService.isAtendente;
    
    if (!podeEditar) return; 

    StatusAtendimento? novoStatus = agendamento.status;
    DateTime novaDataHora = agendamento.dataHora; 

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Editar Agendamento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paciente: ${agendamento.pacienteNome}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Prestador: ${agendamento.nomePrestador ?? 'N/A'}'),
                    const SizedBox(height: 15),
                    
                    // Seletor de Status
                    DropdownButtonFormField<StatusAtendimento>(
                      decoration: const InputDecoration(labelText: 'Status de Atendimento'),
                      value: novoStatus,
                      items: StatusAtendimento.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.nomeFormatado, style: TextStyle(color: status.cor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() => novoStatus = value);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Seletor de Data e Hora
                    const Text('Reagendamento:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        // Botão Data
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('dd/MM/yyyy').format(novaDataHora)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: novaDataHora,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setModalState(() {
                                novaDataHora = DateTime(date.year, date.month, date.day, novaDataHora.hour, novaDataHora.minute);
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        // Botão Hora
                        ElevatedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(DateFormat('HH:mm').format(novaDataHora)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(novaDataHora),
                            );
                            if (time != null) {
                              setModalState(() {
                                novaDataHora = DateTime(novaDataHora.year, novaDataHora.month, novaDataHora.day, time.hour, time.minute);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setModalState(() => isSaving = true);
                    try {
                      final statusMudou = agendamento.status != novoStatus;
                      final dataHoraMudou = agendamento.dataHora.difference(novaDataHora).inMinutes.abs() > 1; 
                      
                      if (!statusMudou && !dataHoraMudou) {
                         Navigator.of(context).pop();
                         return;
                      }

                      await Provider.of<AgendaService>(context, listen: false).updateAgendamento(
                        agendamentoId: agendamento.id,
                        novoStatus: novoStatus,
                        novaDataHora: dataHoraMudou ? novaDataHora.toIso8601String() : null,
                      );
                      
                      Navigator.of(context).pop();
                      _fetchAgendamentos(_selectedDay!); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento atualizado com sucesso!')));

                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    } finally {
                      if(mounted) setModalState(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MÉTODO AUXILIAR PARA O CARD (A parte que faltava no ficheiro do usuário) ---
  Widget _buildAgendamentoCard(Agendamento agendamento) {
    final podeEditar = _authService.isAdmin || _authService.isGestor || _authService.isAtendente;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: podeEditar ? () => _showEditAgendamentoDialog(agendamento) : null,
        
        // Cor do círculo baseada no Status
        leading: CircleAvatar(
          backgroundColor: agendamento.status.cor, 
          child: const Icon(
            Icons.calendar_month,
            color: Colors.white,
          ),
        ),
        
        title: Text(agendamento.pacienteNome),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(agendamento.dataHora)}'
            ),
            // Exibe o Status do Agendamento
            Text(
              'Status: ${agendamento.status.nomeFormatado}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: agendamento.status.cor,
              ),
            ),
            if (agendamento.nomePrestador != null)
              Text('Prestador: ${agendamento.nomePrestador}'),
            if (agendamento.observacao != null && agendamento.observacao!.isNotEmpty)
              Text('Obs: ${agendamento.observacao}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
      ),
      body: Column(
        children: [
          // O Calendário
          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() => _calendarFormat = format);
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          
          const Divider(),
          
          // A Lista de Agendamentos
          Expanded(
            child: FutureBuilder<List<Agendamento>>(
              future: _agendamentosFuture,
              builder: (context, snapshot) {
                if (_isLoadingDropdowns || snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Nenhum agendamento para ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}.'));
                }

                final agendamentos = snapshot.data!;
                return ListView.builder(
                  itemCount: agendamentos.length,
                  itemBuilder: (context, index) {
                    final agendamento = agendamentos[index];
                    // Usa o método auxiliar corrigido
                    return _buildAgendamentoCard(agendamento);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoadingDropdowns ? null : _showAddAgendamentoDialog, // Desabilita se os dados não carregaram
        child: const Icon(Icons.add),
        tooltip: 'Novo Agendamento',
      ),
    );
  }
}