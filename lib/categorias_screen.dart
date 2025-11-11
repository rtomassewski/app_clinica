// lib/categorias_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'financeiro_service.dart'; // Importa o service e os Enums/Modelos

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({Key? key}) : super(key: key);

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  late Future<List<CategoriaFinanceira>> _categoriasFuture;

  @override
  void initState() {
    super.initState();
    _refreshCategorias();
  }

  void _refreshCategorias() {
    setState(() {
      _categoriasFuture =
          Provider.of<FinanceiroService>(context, listen: false).getCategorias();
    });
  }

  // O Modal para Adicionar Categoria
  Future<void> _showAddCategoriaDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    TipoTransacao _tipoSelecionado = TipoTransacao.DESPESA; // Padrão
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Nova Categoria Financeira'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nome da Categoria*'),
                      validator: (value) =>
                          value!.isEmpty ? 'Obrigatório' : null,
                    ),
                    DropdownButtonFormField<TipoTransacao>(
                      value: _tipoSelecionado,
                      decoration: const InputDecoration(labelText: 'Tipo*'),
                      items: const [
                        DropdownMenuItem(value: TipoTransacao.DESPESA, child: Text('Despesa (Saída)')),
                        DropdownMenuItem(value: TipoTransacao.RECEITA, child: Text('Receita (Entrada)')),
                      ],
                      onChanged: (value) {
                        setModalState(() => _tipoSelecionado = value!);
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
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            try {
                              await Provider.of<FinanceiroService>(context, listen: false)
                                  .addCategoria(
                                nome: _nomeController.text,
                                tipo: _tipoSelecionado,
                              );
                              Navigator.of(context).pop();
                              _refreshCategorias(); // Atualiza a lista
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
      appBar: AppBar(
        title: const Text('Plano de Contas (Categorias)'),
      ),
      body: FutureBuilder<List<CategoriaFinanceira>>(
        future: _categoriasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma categoria cadastrada.'));
          }

          final categorias = snapshot.data!;
          return ListView.builder(
            itemCount: categorias.length,
            itemBuilder: (context, index) {
              final cat = categorias[index];
              final isReceita = cat.tipo == 'RECEITA';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isReceita ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isReceita ? Colors.green : Colors.red,
                  ),
                  title: Text(cat.nome),
                  subtitle: Text(cat.tipo),
                  // TODO: Adicionar botões de Editar/Deletar
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoriaDialog,
        child: const Icon(Icons.add),
        tooltip: 'Nova Categoria',
      ),
    );
  }
}