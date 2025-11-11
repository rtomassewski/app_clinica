// lib/agenda_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'paciente_service.dart';

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
  late Future<List<Agendamento>> _agendamentosFuture;
  
  // 1. Listas para os Dropdowns (carregadas no início)
  List<Paciente> _listaPacientes = [];
  List<Profissional> _listaProfissionais = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _pacienteService = Provider.of<PacienteService>(context, listen: false);
    
    // 2. Busca os dados da agenda E os dados dos dropdowns
    _fetchAgendamentos(_selectedDay!);
    _fetchDropdownData();
  }

  // 3. Busca agendamentos (igual a antes)
  void _fetchAgendamentos(DateTime dia) {
    final dataInicio = DateTime(dia.year, dia.month, dia.day, 0, 0, 0);
    final dataFim = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
    setState(() {
      _agendamentosFuture = _pacienteService.getAgendamentos(dataInicio, dataFim);
    });
  }
  
  // 4. (NOVO) Busca dados para os modais
  Future<void> _fetchDropdownData() async {
    try {
      final pacientes = await _pacienteService.getPacientes();
      final profissionais = await _pacienteService.getProfissionais();
      setState(() {
        _listaPacientes = pacientes;
        _listaProfissionais = profissionais;
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      // Tratar erro se não conseguir carregar os dropdowns
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

  // 5. (NOVO) A função que constrói e exibe o modal
  Future<void> _showAddAgendamentoDialog() async {
    // Se os dados do dropdown não carregaram, não abra o modal
    if (_isLoadingDropdowns) return;

    // Controladores do formulário
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
        // StatefulBuilder para gerenciar o estado INTERNO do modal
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Helper para selecionar data
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

            // Helper para selecionar hora
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
                        await _pacienteService.addAgendamento(
                          pacienteId: _pacienteSelecionado!.id,
                          usuarioId: _profissionalSelecionado!.id,
                          dataHoraInicio: _dataHoraInicio,
                          dataHoraFim: _dataHoraInicio.add(_duracao),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum agendamento para este dia.'));
                }

                final agendamentos = snapshot.data!;
                return ListView.builder(
                  itemCount: agendamentos.length,
                  itemBuilder: (context, index) {
                    final agendamento = agendamentos[index];
                    final inicio = DateFormat('HH:mm').format(agendamento.dataHoraInicio.toLocal());
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(agendamento.nomePaciente),
                        subtitle: Text('Profissional: ${agendamento.nomeProfissional}'),
                        trailing: Text(inicio),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // 6. (NOVO) Chama a função do modal
        onPressed: _showAddAgendamentoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Agendamento',
      ),
    );
  }
}