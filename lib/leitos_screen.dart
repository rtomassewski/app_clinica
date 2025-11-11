// lib/leitos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'internacao_service.dart';
import 'paciente_service.dart';

class LeitosScreen extends StatefulWidget {
  // 1. Recebe os parâmetros
  final int quartoId;
  final String quartoNome;

  const LeitosScreen({
    Key? key,
    required this.quartoId,
    required this.quartoNome,
  }) : super(key: key);

  @override
  State<LeitosScreen> createState() => _LeitosScreenState();
}

class _LeitosScreenState extends State<LeitosScreen> {
  late Future<List<Leito>> _leitosFuture;

  @override
  void initState() {
    super.initState();
    _refreshLeitos();
  }

  void _refreshLeitos() {
    setState(() {
      _leitosFuture = Provider.of<InternacaoService>(context, listen: false)
          .getLeitos(widget.quartoId);
    });
  }

  // 3. Modal para Adicionar Leito
  Future<void> _showAddLeitoDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Novo Leito no ${widget.quartoNome}'),
              content: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nomeController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome do Leito* (Ex: A, B, 1)'),
                  validator: (value) =>
                      value!.isEmpty ? 'Obrigatório' : null,
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
                              await Provider.of<InternacaoService>(context, listen: false)
                                  .addLeito(
                                nome: _nomeController.text,
                                quartoId: widget.quartoId, // 4. Usa o ID do Quarto
                              );
                              Navigator.of(context).pop();
                              _refreshLeitos();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro: $e'),
                                  backgroundColor: Colors.red,
                                ),
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

  // 5. (NOVO) Define a cor do Leito
  Color _getLeitoColor(StatusLeito status) {
    switch (status) {
      case StatusLeito.OCUPADO:
        return Colors.red.shade400;
      case StatusLeito.DISPONIVEL:
        return Colors.green.shade400;
      case StatusLeito.RESERVADO:
        return Colors.blue.shade400;
      case StatusLeito.MANUTENCAO:
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  // 6. (NOVO) Define o ícone do Leito
  IconData _getLeitoIcon(StatusLeito status) {
    switch (status) {
      case StatusLeito.OCUPADO:
        return Icons.bed_sharp;
      case StatusLeito.DISPONIVEL:
        return Icons.bed_outlined;
      default:
        return Icons.bedtime_outlined;
    }
  }

  // 7. Ação de clique no Leito (Check-in)
  void _onLeitoTapped(Leito leito) {
    if (leito.status == StatusLeito.DISPONIVEL) {
      _showCheckInDialog(leito);
    } 
    else if (leito.status == StatusLeito.OCUPADO) {
      // IMPLEMENTAÇÃO DO CHECK-OUT
      _showCheckOutDialog(leito);
    }
    // (Ignora cliques em leitos em Manutenção/Reservado)
  }

  // --- ADICIONE ESTE NOVO MÉTODO (O MODAL) ---
  Future<void> _showCheckInDialog(Leito leito) async {
    // Busca os pacientes disponíveis (sem leito)
    // (O 'internacaoService' é pego pelo Provider)
    final internacaoService = Provider.of<InternacaoService>(context, listen: false);
    
    // Mostra um loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    List<Paciente> pacientesDisponiveis = [];
    String? erroBusca;
    try {
      pacientesDisponiveis = await internacaoService.getPacientesSemLeito();
    } catch (e) {
      erroBusca = e.toString();
    }
    
    Navigator.of(context).pop(); // Fecha o loading
    
    if (erroBusca != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroBusca)));
      return;
    }

    // --- Inicia os controles do formulário ---
    Paciente? _pacienteSelecionado;
    bool _isSaving = false;
    
    // 2. Mostra o Diálogo de Fato
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Check-in no ${leito.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pacientesDisponiveis.isEmpty)
                      const Text('Nenhum paciente aguardando internação (sem leito).')
                    else
                      DropdownButtonFormField<Paciente>(
                        value: _pacienteSelecionado,
                        hint: const Text('Selecione o Paciente'),
                        items: pacientesDisponiveis.map((paciente) {
                          return DropdownMenuItem(
                            value: paciente,
                            child: Text(paciente.nomeCompleto),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => _pacienteSelecionado = value);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (_pacienteSelecionado == null || _isSaving)
                      ? null // Desabilita o botão se nada foi selecionado
                      : () async {
                          setModalState(() => _isSaving = true);
                          try {
                            // Chama a API de Check-in
                            await internacaoService.checkInPaciente(
                              _pacienteSelecionado!.id,
                              leito.id,
                            );
                            Navigator.of(context).pop(); // Fecha o modal
                            _refreshLeitos(); // Atualiza a lista de leitos
                            
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
                      : const Text('Confirmar Check-in'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCheckOutDialog(Leito leito) async {
    // 1. Validação (Garante que temos os dados necessários)
    if (leito.pacienteId == null || leito.pacienteNome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Dados do paciente incompletos no leito.')),
      );
      return;
    }

    final internacaoService = Provider.of<InternacaoService>(context, listen: false);
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Confirmar Check-out?'),
              content: SingleChildScrollView(
                child: Text('Deseja realmente liberar o leito ${leito.nome} ocupado por ${leito.pacienteNome}?'),
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
                          setModalState(() => _isSaving = true);
                          try {
                            // Chama a API de Check-out
                            await internacaoService.checkOutPaciente(
                              leito.pacienteId!,
                            );
                            
                            Navigator.of(context).pop(); // Fecha o modal
                            _refreshLeitos(); // Atualiza a lista
                            
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            setModalState(() => _isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // Botão vermelho
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Confirmar Check-out'),
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
        title: Text(widget.quartoNome), // 8. Título dinâmico
      ),
      body: FutureBuilder<List<Leito>>(
        future: _leitosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum leito cadastrado neste quarto.'));
          }

          final leitos = snapshot.data!;
          return ListView.builder(
            itemCount: leitos.length,
            itemBuilder: (context, index) {
              final leito = leitos[index];
              return Card(
                color: _getLeitoColor(leito.status).withOpacity(0.1), // Cor de fundo suave
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    _getLeitoIcon(leito.status),
                    color: _getLeitoColor(leito.status), // Cor do ícone
                    size: 40,
                  ),
                  title: Text(leito.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Mostra o paciente se estiver ocupado, ou o status
                  subtitle: Text(
                    leito.status == StatusLeito.OCUPADO
                        ? leito.pacienteNome ?? 'Ocupado (Erro de dados)'
                        : leito.status.name.toString(), // "DISPONIVEL", "MANUTENCAO"
                  ),
                  onTap: () => _onLeitoTapped(leito),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLeitoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Leito',
      ),
    );
  }
}