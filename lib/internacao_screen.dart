// lib/internacao_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'internacao_service.dart';
// (Precisamos do dart:convert para o service)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'quartos_screen.dart';


// (Verifique se o 'internacao_service.dart' tem o 'addAla' e a 'Ala')
// (Vou assumir que o 'internacao_service.dart' está correto)


class InternacaoScreen extends StatefulWidget {
  const InternacaoScreen({Key? key}) : super(key: key);

  @override
  State<InternacaoScreen> createState() => _InternacaoScreenState();
}

class _InternacaoScreenState extends State<InternacaoScreen> {
  late Future<List<Ala>> _alasFuture;

  @override
  void initState() {
    super.initState();
    _refreshAlas();
  }

  void _refreshAlas() {
    setState(() {
      _alasFuture =
          Provider.of<InternacaoService>(context, listen: false).getAlas();
    });
  }

  // --- ESTA É A FUNÇÃO DO MODAL (NO LUGAR CORRETO) ---
  Future<void> _showAddAlaDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _descricaoController = TextEditingController();
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Adicionar Nova Ala'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nome da Ala*'),
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
                              // Chama a API
                              await Provider.of<InternacaoService>(context, listen: false)
                                  .addAla(
                                nome: _nomeController.text,
                                descricao: _descricaoController.text.isEmpty
                                    ? null
                                    : _descricaoController.text,
                              );

                              Navigator.of(context).pop(); // Fecha o modal
                              _refreshAlas(); // Atualiza a lista

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

  void _navegarParaQuartos(Ala ala) {
    // Ação de clique: Navegar para a tela de Quartos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuartosScreen(
          alaId: ala.id,
          alaNome: ala.nome,
        ),
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Leitos (Alas)'),
      ),
      body: FutureBuilder<List<Ala>>(
        future: _alasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma ala cadastrada.'));
          }

          final alas = snapshot.data!;
          return ListView.builder(
            itemCount: alas.length,
            itemBuilder: (context, index) {
              final ala = alas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.maps_home_work_outlined),
                  title: Text(ala.nome),
                  subtitle: Text(ala.descricao ?? 'Sem descrição'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navegarParaQuartos(ala),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAlaDialog,
        child: const Icon(Icons.add),
        tooltip: 'Nova Ala',
      ),
    );
  }
}