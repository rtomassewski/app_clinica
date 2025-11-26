// lib/agenda_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'paciente_service.dart' hide Agendamento;
import 'agenda_service.dart';
import 'auth_service.dart';
import 'procedimento_service.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({Key? key}) : super(key: key);

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late PacienteService _pacienteService;
  late AgendaService _agendaService;
  late AuthService _authService;
  late ProcedimentoService _procedimentoService;

  late Future<List<Agendamento>> _agendamentosFuture;
  
  List<Paciente> _listaPacientes = [];
  List<Profissional> _listaProfissionais = [];
  List<Procedimento> _listaProcedimentos = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Inicializa os services
    _pacienteService = Provider.of<PacienteService>(context, listen: false);
    _agendaService = Provider.of<AgendaService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _procedimentoService = Provider.of<ProcedimentoService>(context, listen: false);
    
    _fetchAgendamentos(_selectedDay!);
    _fetchDropdownData();
  }

  void _fetchAgendamentos(DateTime dia) {
    final dataInicio = DateTime(dia.year, dia.month, dia.day);
    setState(() {
      _agendamentosFuture = _agendaService.getAgendamentos(date: dataInicio);
    });
  }
  
  Future<void> _fetchDropdownData() async {
    try {
      final pacientes = await _pacienteService.getPacientes();
      final todosProfissionais = await _pacienteService.getProfissionais(); 
      final procedimentos = await _procedimentoService.getProcedimentos();

      // --- FILTRO DE PROFISSIONAIS ---
      // Lista de cargos permitidos (Certifique-se que está igual ao seu Banco de Dados/Enum)
      final cargosPermitidos = [
        'MEDICO', 
        'MEDICA',
        'PSICOLOGO', 
        'PSICOLOGA',
        'PSIQUIATRA', 
        'TERAPEUTA', 
        'ENFERMEIRO', 
        'ENFERMEIRA',
        'DENTISTA',
        'FISIOTERAPEUTA',
        'NUTRICIONISTA'
      ];

      final profissionaisFiltrados = todosProfissionais.where((p) {
        // Verifica se o profissional tem papel definido e se está na lista permitida
        // (Usa toUpperCase para evitar erro de maiúscula/minúscula)
        final papel = p.papel?.toUpperCase() ?? ''; 
        return cargosPermitidos.contains(papel);
      }).toList();
      // -------------------------------

      if (mounted) {
        setState(() {
          _listaPacientes = pacientes;
          _listaProfissionais = profissionaisFiltrados; // <-- Usa a lista filtrada
          // Filtra apenas serviços ativos
          _listaProcedimentos = procedimentos.where((p) => p.ativo).toList(); 
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
       print("Erro ao carregar dropdowns: $e");
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

  // --- MODAL DE ADICIONAR AGENDAMENTO ---
  Future<void> _showAddAgendamentoDialog() async {
    if (_isLoadingDropdowns) return;
    Paciente? _pacienteSelecionado;
    Profissional? _profissionalSelecionado;
    
    // Define a hora inicial
    DateTime _dataHoraInicio = _selectedDay ?? DateTime.now();
    if (_selectedDay != null && _dataHoraInicio.hour == 0) {
      _dataHoraInicio = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 9, 0);
    }
    
    TimeOfDay _horaInicio = TimeOfDay.fromDateTime(_dataHoraInicio);
    TextEditingController _obsController = TextEditingController();
    
    // Lista de IDs selecionados
    List<int> _procedimentosSelecionados = []; 
    
    final _formKey = GlobalKey<FormState>();
    bool _isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
            
            // Helper para calcular total dinamicamente
            double _calcularTotal() {
              double total = 0;
              for (var id in _procedimentosSelecionados) {
                final proc = _listaProcedimentos.firstWhere((element) => element.id == id);
                total += proc.valor;
              }
              return total;
            }

            Future<void> _selecionarData(BuildContext context) async {
              final DateTime? picked = await showDatePicker(
                context: context, 
                initialDate: _dataHoraInicio, 
                firstDate: DateTime(2020), 
                lastDate: DateTime(2030)
              );
              if (picked != null) {
                setModalState(() => _dataHoraInicio = DateTime(picked.year, picked.month, picked.day, _horaInicio.hour, _horaInicio.minute));
              }
            }

            Future<void> _selecionarHora(BuildContext context) async {
              final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _horaInicio);
              if (picked != null) {
                setModalState(() { 
                  _horaInicio = picked; 
                  _dataHoraInicio = DateTime(_dataHoraInicio.year, _dataHoraInicio.month, _dataHoraInicio.day, _horaInicio.hour, _horaInicio.minute); 
                });
              }
            }

            return AlertDialog(
              title: const Text('Novo Agendamento'),
              // CORREÇÃO: SizedBox com width maxFinite evita o erro de layout
              content: SizedBox(
                width: double.maxFinite, 
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Paciente
                        DropdownButtonFormField<Paciente>(
                          value: _pacienteSelecionado, 
                          hint: const Text('Selecione um Paciente'), 
                          isExpanded: true,
                          items: _listaPacientes.map((p) => DropdownMenuItem(value: p, child: Text(p.nomeCompleto))).toList(), 
                          onChanged: (v) => setModalState(() => _pacienteSelecionado = v), 
                          validator: (v) => v == null ? 'Obrigatório' : null
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Profissional
                        DropdownButtonFormField<Profissional>(
                          value: _profissionalSelecionado, 
                          hint: const Text('Selecione um Profissional'), 
                          isExpanded: true,
                          items: _listaProfissionais.map((p) => DropdownMenuItem(value: p, child: Text(p.nomeCompleto))).toList(), 
                          onChanged: (v) => setModalState(() => _profissionalSelecionado = v), 
                          validator: (v) => v == null ? 'Obrigatório' : null
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // --- SELETOR DE PROCEDIMENTOS ---
                        const Text('Procedimentos:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          height: 150, // Altura fixa para a lista
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300), 
                            borderRadius: BorderRadius.circular(5)
                          ),
                          child: ListView(
                            // shrinkWrap removido ou mantido false aqui pois temos altura fixa
                            children: _listaProcedimentos.map((proc) {
                              final isSelected = _procedimentosSelecionados.contains(proc.id);
                              return CheckboxListTile(
                                dense: true,
                                title: Text(proc.nome),
                                subtitle: Text('R\$ ${proc.valor.toStringAsFixed(2)}'),
                                value: isSelected,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      _procedimentosSelecionados.add(proc.id);
                                    } else {
                                      _procedimentosSelecionados.remove(proc.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        
                        // Mostra o Total Estimado
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Valor Total: R\$ ${_calcularTotal().toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                        
                        TextFormField(
                          controller: _obsController, 
                          decoration: const InputDecoration(labelText: 'Observação'), 
                          maxLines: 2
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                          children: [
                            ElevatedButton(
                              onPressed: () => _selecionarData(context), 
                              child: Text(DateFormat('dd/MM').format(_dataHoraInicio))
                            ), 
                            ElevatedButton(
                              onPressed: () => _selecionarHora(context), 
                              child: Text(_horaInicio.format(context))
                            )
                          ]
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), 
                  child: const Text('Cancelar')
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setModalState(() => _isSaving = true);
                      try {
                        // ENVIA OS DADOS (Incluindo a lista de IDs)
                        await _agendaService.addAgendamento(
                          pacienteId: _pacienteSelecionado!.id, 
                          usuarioId: _profissionalSelecionado!.id, 
                          data_hora_inicio: _dataHoraInicio.toIso8601String(), 
                          observacao: _obsController.text.isNotEmpty ? _obsController.text : null,
                          procedimentoIds: _procedimentosSelecionados, // <-- ENVIA A LISTA
                        );
                        Navigator.of(context).pop();
                        _fetchAgendamentos(_selectedDay!);
                      } catch (e) { 
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); 
                      } finally { 
                        if(mounted) setModalState(() => _isSaving = false); 
                      }
                    }
                  }, 
                  child: _isSaving 
                    ? const CircularProgressIndicator(strokeWidth: 2) 
                    : const Text('Salvar')
                ),
              ],
            );
          });
      },
    );
  }

  // --- MODAL EDITAR AGENDAMENTO ---
  Future<void> _showEditAgendamentoDialog(Agendamento agendamento) async {
    final podeEditar = _authService.isAdmin || _authService.isGestor || _authService.isAtendente;
    if (!podeEditar) return; 

    StatusAtendimento? novoStatus = agendamento.status;
    DateTime novaDataHora = agendamento.dataHora; 
    TextEditingController obsController = TextEditingController(text: agendamento.observacao);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isSaving = false;
        return StatefulBuilder(builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Editar Agendamento'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Paciente: ${agendamento.pacienteNome}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // Mostra os procedimentos e valor total (Somente leitura aqui)
                  if (agendamento.procedimentosNomes.isNotEmpty) ...[
                    const Align(alignment: Alignment.centerLeft, child: Text("Procedimentos:", style: TextStyle(fontSize: 12, color: Colors.grey))),
                    ...agendamento.procedimentosNomes.map((p) => Align(alignment: Alignment.centerLeft, child: Text("• $p", style: const TextStyle(fontSize: 13)))),
                    const SizedBox(height: 5),
                    Align(alignment: Alignment.centerLeft, child: Text("Valor Total: R\$ ${agendamento.valorTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 15),
                  ],
                  
                  DropdownButtonFormField<StatusAtendimento>(
                    decoration: const InputDecoration(labelText: 'Status'), 
                    value: novoStatus, 
                    items: StatusAtendimento.values.map((s) => DropdownMenuItem(value: s, child: Text(s.nomeFormatado, style: TextStyle(color: s.cor)))).toList(), 
                    onChanged: (v) => setModalState(() => novoStatus = v)
                  ),
                  const SizedBox(height: 15),
                  TextFormField(controller: obsController, decoration: const InputDecoration(labelText: 'Observação'), maxLines: 2),
                  const SizedBox(height: 20),
                  const Text('Reagendamento:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(children: [
                      ElevatedButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: novaDataHora, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setModalState(() => novaDataHora = DateTime(d.year, d.month, d.day, novaDataHora.hour, novaDataHora.minute)); }, child: Text(DateFormat('dd/MM').format(novaDataHora))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(novaDataHora)); if (t != null) setModalState(() => novaDataHora = DateTime(novaDataHora.year, novaDataHora.month, novaDataHora.day, t.hour, t.minute)); }, child: Text(DateFormat('HH:mm').format(novaDataHora))),
                  ]),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(onPressed: isSaving ? null : () async {
                  setModalState(() => isSaving = true);
                  try {
                    final statusMudou = agendamento.status != novoStatus;
                    final dataHoraMudou = agendamento.dataHora.difference(novaDataHora).inMinutes.abs() > 1; 
                    final observacaoMudou = agendamento.observacao != obsController.text;
                    
                    if (!statusMudou && !dataHoraMudou && !observacaoMudou) { 
                      Navigator.of(context).pop(); 
                      return; 
                    }
                    
                    await Provider.of<AgendaService>(context, listen: false).updateAgendamento(
                      agendamentoId: agendamento.id, 
                      novoStatus: novoStatus, 
                      novaDataHora: dataHoraMudou ? novaDataHora.toIso8601String() : null, 
                      observacao: obsController.text
                    );
                    Navigator.of(context).pop(); 
                    _fetchAgendamentos(_selectedDay!);
                  } catch (e) { 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); 
                  } finally { 
                    if(mounted) setModalState(() => isSaving = false); 
                  }
                }, child: isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Salvar')),
              ],
            );
          });
      },
    );
  }

  // --- LAYOUT E WIDGETS ---
  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          locale: 'pt_BR', 
          firstDay: DateTime.utc(2020, 1, 1), 
          lastDay: DateTime.utc(2030, 12, 31), 
          focusedDay: _focusedDay, 
          calendarFormat: _calendarFormat, 
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          onFormatChanged: (format) { if (_calendarFormat != format) setState(() => _calendarFormat = format); },
          onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
          headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
        ),
      ),
    );
  }

  Widget _buildAgendamentoList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Atendimentos de ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}", style: Theme.of(context).textTheme.headlineSmall),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<Agendamento>>(
            future: _agendamentosFuture,
            builder: (context, snapshot) {
              if (_isLoadingDropdowns || snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 50, color: Colors.grey[400]), const SizedBox(height: 10), const Text('Nenhum agendamento.', style: TextStyle(color: Colors.grey))]));

              final agendamentos = snapshot.data!;
              return ListView.builder(
                itemCount: agendamentos.length, 
                padding: const EdgeInsets.all(8), 
                itemBuilder: (context, index) => _buildAgendamentoCard(agendamentos[index])
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgendamentoCard(Agendamento agendamento) {
    final podeEditar = _authService.isAdmin || _authService.isGestor || _authService.isAtendente;
    final pacienteNome = agendamento.pacienteNome ?? 'Paciente Desconhecido';

    // Monta string de serviços (ex: "Consulta + Exame")
    String servicosStr = "";
    if (agendamento.procedimentosNomes.isNotEmpty) {
      servicosStr = agendamento.procedimentosNomes.join(" + ");
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        onTap: podeEditar ? () => _showEditAgendamentoDialog(agendamento) : null,
        leading: CircleAvatar(backgroundColor: agendamento.status.cor, child: const Icon(Icons.calendar_month, color: Colors.white)),
        title: Text(pacienteNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]), const SizedBox(width: 4),
                Text(DateFormat('HH:mm').format(agendamento.dataHora), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: agendamento.status.cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: agendamento.status.cor)), child: Text(agendamento.status.nomeFormatado, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: agendamento.status.cor))),
            ]),
            
            // --- EXIBE OS SERVIÇOS E VALOR NO CARD ---
            if (servicosStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Serviços: $servicosStr', style: const TextStyle(color: Colors.black87)),
              ),
             if (agendamento.valorTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Total: R\$ ${agendamento.valorTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
            // ------------------------------------------
            
            if (agendamento.nomePrestador != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Profissional: ${agendamento.nomePrestador}')),
            if (agendamento.observacao != null && agendamento.observacao!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Obs: ${agendamento.observacao}', style: const TextStyle(fontStyle: FontStyle.italic))),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width > 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: isWideScreen
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 350, child: SingleChildScrollView(child: _buildCalendar())), const VerticalDivider(width: 1), Expanded(child: _buildAgendamentoList())])
          : Column(children: [_buildCalendar(), const Divider(height: 1), Expanded(child: _buildAgendamentoList())]),
      floatingActionButton: FloatingActionButton(onPressed: _isLoadingDropdowns ? null : _showAddAgendamentoDialog, child: const Icon(Icons.add), tooltip: 'Novo Agendamento'),
    );
  }
}