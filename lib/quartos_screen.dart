// lib/quartos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'internacao_service.dart';
import 'leitos_screen.dart';

class QuartosScreen extends StatefulWidget {
  // 1. Recebe os parâmetros da tela anterior
  final int alaId;
  final String alaNome;

  const QuartosScreen({
    Key? key,
    required this.alaId,
    required this.alaNome,
  }) : super(key: key);

  @override
  State<QuartosScreen> createState() => _QuartosScreenState();
}

class _QuartosScreenState extends State<QuartosScreen> {
  late Future<List<Quarto>> _quartosFuture;

  @override
  void initState() {
    super.initState();
    _refreshQuartos();
  }

  void _refreshQuartos() {
    setState(() {
      // 2. Chama o service usando o 'widget.alaId'
      _quartosFuture = Provider.of<InternacaoService>(context, listen: false)
          .getQuartos(widget.alaId);
    });
  }

  // 3. Modal para Adicionar Quarto
  Future<void> _showAddQuartoDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _descricaoController = TextEditingController();
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Novo Quarto na ${widget.alaNome}'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nome do Quarto*'),
                      validator: (value) =>
                          value!.isEmpty ? 'Obrigatório' : null,
                    ),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: 'Descrição (Opcional)'),
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
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            try {
                              await Provider.of<InternacaoService>(context, listen: false)
                                  .addQuarto(
                                nome: _nomeController.text,
                                descricao: _descricaoController.text.isEmpty
                                    ? null
                                    : _descricaoController.text,
                                alaId: widget.alaId, // 4. Usa o ID da Ala
                              );
                              Navigator.of(context).pop();
                              _refreshQuartos();
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
  
  void _navegarParaLeitos(Quarto quarto) {
    // Ação de clique: Navegar para a tela de Leitos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeitosScreen(
          quartoId: quarto.id,
          quartoNome: quarto.nome,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alaNome), // 5. Título dinâmico
      ),
      body: FutureBuilder<List<Quarto>>(
        future: _quartosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum quarto cadastrado nesta ala.'));
          }

          final quartos = snapshot.data!;
          return ListView.builder(
            itemCount: quartos.length,
            itemBuilder: (context, index) {
              final quarto = quartos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text(quarto.nome),
                  subtitle: Text(quarto.descricao ?? 'Sem descrição'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navegarParaLeitos(quarto),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddQuartoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Quarto',
      ),
    );
  }
}