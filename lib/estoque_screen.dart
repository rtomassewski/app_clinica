// lib/estoque_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'estoque_service.dart';

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({Key? key}) : super(key: key);

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  late Future<List<ProdutoEstoque>> _produtosFuture;

  @override
  void initState() {
    super.initState();
    _refreshProdutos();
  }

  void _refreshProdutos() {
    setState(() {
      _produtosFuture =
          Provider.of<EstoqueService>(context, listen: false).getProdutos();
    });
  }

  // --- MODAL 1: CRIAR NOVO PRODUTO ---
  Future<void> _showAddProdutoDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _minimoController = TextEditingController(text: '0');
    UnidadeMedida _unidadeSelecionada = UnidadeMedida.UNIDADE;
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Novo Produto no Catálogo'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nome do Produto*'),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                      DropdownButtonFormField<UnidadeMedida>(
                        value: _unidadeSelecionada,
                        decoration: const InputDecoration(labelText: 'Unidade*'),
                        items: UnidadeMedida.values.map((unidade) {
                          return DropdownMenuItem(value: unidade, child: Text(unidade.name));
                        }).toList(),
                        onChanged: (v) => setModalState(() => _unidadeSelecionada = v!),
                      ),
                      TextFormField(
                        controller: _minimoController,
                        decoration: const InputDecoration(labelText: 'Estoque Mínimo*'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '-1') ?? -1) < 0 ? 'Inválido' : null,
                      ),
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
                        await Provider.of<EstoqueService>(context, listen: false)
                            .addProduto(
                          nome: _nomeController.text,
                          unidade: _unidadeSelecionada,
                          estoqueMinimo: int.parse(_minimoController.text),
                        );
                        Navigator.of(context).pop();
                        _refreshProdutos();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                        setModalState(() => _isSaving = false);
                      }
                    }
                  },
                  child: _isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Salvar Produto'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // --- MODAL 2: DAR ENTRADA EM PRODUTO EXISTENTE ---
  Future<void> _showAddEntradaDialog(ProdutoEstoque produto) async {
    final _formKey = GlobalKey<FormState>();
    final _qtdController = TextEditingController();
    final _loteController = TextEditingController();
    final _validadeController = TextEditingController(); // Formato: AAAA-MM-DD
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Dar Entrada em: ${produto.nome}'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _qtdController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Quantidade*'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0 ? 'Inválido' : null,
                      ),
                      TextFormField(
                        controller: _loteController,
                        decoration: const InputDecoration(labelText: 'Lote (Opcional)'),
                      ),
                      TextFormField(
                        controller: _validadeController,
                        decoration: const InputDecoration(labelText: 'Validade (Opcional)', hintText: 'AAAA-MM-DD'),
                        keyboardType: TextInputType.datetime,
                      ),
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
                        await Provider.of<EstoqueService>(context, listen: false)
                            .addEntradaEstoque(
                          produtoId: produto.id,
                          quantidade: int.parse(_qtdController.text),
                          lote: _loteController.text.isEmpty ? null : _loteController.text,
                          dataValidade: _validadeController.text.isEmpty ? null : _validadeController.text,
                        );
                        Navigator.of(context).pop();
                        _refreshProdutos(); // Atualiza a lista principal
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                        setModalState(() => _isSaving = false);
                      }
                    }
                  },
                  child: _isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Confirmar Entrada'),
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
        title: const Text('Gestão de Estoque (Farmácia)'),
      ),
      body: FutureBuilder<List<ProdutoEstoque>>(
        future: _produtosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado no catálogo.'));
          }

          final produtos = snapshot.data!;
          return ListView.builder(
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
              // Alerta de estoque baixo (Lógica Corrigida)
              final bool estoqueBaixo = produto.estoqueMinimo > 0 && 
                                        produto.quantidadeEstoque <= produto.estoqueMinimo;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estoqueBaixo ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      estoqueBaixo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: estoqueBaixo ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                  title: Text(produto.nome),
                  subtitle: Text('Estoque Atual: ${produto.quantidadeEstoque} ${produto.unidadeMedida.name}'),
                  trailing: ElevatedButton(
                    child: const Text('Dar Entrada'),
                    onPressed: () => _showAddEntradaDialog(produto),
                  ),
                  // TODO: Adicionar 'onTap' para ver histórico
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProdutoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Produto',
      ),
    );
  }
}