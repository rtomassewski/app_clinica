// lib/meus_atendimentos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'agenda_service.dart';
import 'auth_service.dart';
import 'evolucao_service.dart';

class MeusAtendimentosScreen extends StatefulWidget {
  const MeusAtendimentosScreen({Key? key}) : super(key: key);

  @override
  State<MeusAtendimentosScreen> createState() => _MeusAtendimentosScreenState();
}

class _MeusAtendimentosScreenState extends State<MeusAtendimentosScreen> {
  late Future<List<Agendamento>> _agendamentosFuture;

  @override
  void initState() {
    super.initState();
    _carregarAgendaHoje();
  }

  void _carregarAgendaHoje() {
    setState(() {
      final hoje = DateTime.now();
      _agendamentosFuture = Provider.of<AgendaService>(context, listen: false)
          .getAgendamentos(date: hoje);
    });
  }

  void _abrirProntuario(BuildContext context, Agendamento agendamento) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogEvolucao(
        agendamento: agendamento, 
        onFinalizar: _carregarAgendaHoje
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.usuarioLogado?.id ?? 0; 

    // Usamos DefaultTabController para criar as abas
    return DefaultTabController(
      length: 2, // Duas abas: Pendentes e Realizados
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Painel do Especialista"),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.assignment_ind), text: "A Realizar"),
              Tab(icon: Icon(Icons.check_circle), text: "Realizados"),
            ],
          ),
        ),
        body: FutureBuilder<List<Agendamento>>(
          future: _agendamentosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erro: ${snapshot.error}"));
            }
            
            final listaTotal = snapshot.data ?? [];

            // 1. Filtra Pendentes (Agendado)
            final pendentes = listaTotal.where((ag) {
              return ag.userId == userId && 
                     ag.status == StatusAtendimento.AGENDADO;
            }).toList();

            // 2. Filtra Realizados (Realizado)
            final realizados = listaTotal.where((ag) {
              return ag.userId == userId && 
                     ag.status == StatusAtendimento.REALIZADO;
            }).toList();

            return TabBarView(
              children: [
                // ABA 1: Pendentes
                _buildLista(pendentes, isRealizado: false),

                // ABA 2: Realizados
                _buildLista(realizados, isRealizado: true),
              ],
            );
          },
        ),
      ),
    );
  }

  // Método auxiliar para montar a lista visual
  Widget _buildLista(List<Agendamento> lista, {required bool isRealizado}) {
    if (lista.isEmpty) {
      return _emptyState(isRealizado 
          ? "Nenhum atendimento realizado hoje." 
          : "Tudo pronto! Nenhum paciente aguardando.");
    }

    return ListView.builder(
      itemCount: lista.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ag = lista[index];
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Se realizado, deixa o card levemente cinza/verde
          color: isRealizado ? Colors.green.withOpacity(0.05) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isRealizado ? Colors.green : Colors.teal,
                      child: Icon(
                        isRealizado ? Icons.check : Icons.person, 
                        color: Colors.white
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ag.pacienteNome ?? "Paciente",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Horário: ${DateFormat('HH:mm').format(ag.dataHora)}",
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (isRealizado)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: const Text(
                          "CONCLUÍDO", 
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                        ),
                      )
                  ],
                ),
                const Divider(height: 20),
                if (ag.procedimentosNomes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text("Procedimentos: ${ag.procedimentosNomes.join(', ')}", style: const TextStyle(fontSize: 13)),
                  ),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(isRealizado ? Icons.edit_note : Icons.medical_services_outlined),
                    label: Text(isRealizado ? "EDITAR EVOLUÇÃO" : "INICIAR ATENDIMENTO"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRealizado ? Colors.grey[700] : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _abrirProntuario(context, ag),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}

// --- MODAL DE EVOLUÇÃO ---
class DialogEvolucao extends StatefulWidget {
  final Agendamento agendamento;
  final VoidCallback onFinalizar;

  const DialogEvolucao({Key? key, required this.agendamento, required this.onFinalizar}) : super(key: key);

  @override
  State<DialogEvolucao> createState() => _DialogEvolucaoState();
}

class _DialogEvolucaoState extends State<DialogEvolucao> {
  final _textoController = TextEditingController();
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Registro Clínico", style: TextStyle(fontSize: 14, color: Colors.grey)),
          Text(widget.agendamento.pacienteNome ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textoController,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Descreva a evolução do paciente, queixas e conduta...",
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _salvando ? null : _salvar,
          child: _salvando 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text("FINALIZAR & SALVAR"),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    if (_textoController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A evolução está muito curta.")));
      return;
    }

    setState(() => _salvando = true);

    try {
      // 1. Cria a evolução no banco
      await Provider.of<EvolucaoService>(context, listen: false).criarEvolucao(
        pacienteId: widget.agendamento.pacienteId,
        agendamentoId: widget.agendamento.id,
        descricao: _textoController.text,
        tipo: 'GERAL', 
      );
      
      // 2. Atualiza o status do agendamento para REALIZADO (se ainda não estiver)
      if (widget.agendamento.status != StatusAtendimento.REALIZADO) {
         await Provider.of<AgendaService>(context, listen: false).updateAgendamento(
           agendamentoId: widget.agendamento.id,
           novoStatus: StatusAtendimento.REALIZADO
         );
      }

      if (mounted) {
        Navigator.pop(context); 
        widget.onFinalizar();   
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Atendimento finalizado com sucesso!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}