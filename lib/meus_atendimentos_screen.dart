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

  // Função corrigida com o parêntese e a chave certas
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
    
    // Pega o ID do usuário logado com segurança
    final userId = authService.usuarioLogado?.id ?? 0; 

    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel do Especialista"),
        backgroundColor: Colors.teal,
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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _emptyState("Sem agendamentos para hoje.");
          }

          // Filtra: Apenas meus agendamentos pendentes
          final meusAtendimentos = snapshot.data!.where((ag) {
            final ehMeu = ag.userId == userId; 
            final estaPendente = ag.status != StatusAtendimento.REALIZADO && 
                                 ag.status != StatusAtendimento.CANCELADO;
            return ehMeu && estaPendente;
          }).toList();

          if (meusAtendimentos.isEmpty) {
             return _emptyState("Nenhum paciente aguardando atendimento.");
          }

          return ListView.builder(
            itemCount: meusAtendimentos.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final ag = meusAtendimentos[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.person, color: Colors.white),
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
                          icon: const Icon(Icons.medical_services_outlined),
                          label: const Text("INICIAR ATENDIMENTO"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
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
        },
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
} // <--- AQUI fecha a classe _MeusAtendimentosScreenState

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
      await Provider.of<EvolucaoService>(context, listen: false).criarEvolucao(
        pacienteId: widget.agendamento.pacienteId,
        agendamentoId: widget.agendamento.id,
        descricao: _textoController.text,
        tipo: 'GERAL', 
      );

      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        widget.onFinalizar();   // Atualiza a lista da tela anterior
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