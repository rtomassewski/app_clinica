// lib/estoque_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'estoque_service.dart'; // Importa a classe Produto e o Service

// Enum para o Dropdown (Pode manter aqui ou mover para um arquivo de utils)
enum UnidadeMedida { UNIDADE, CAIXA, FRASCO, ML }

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({Key? key}) : super(key: key);

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  // Agora usamos a tipagem forte da classe Produto
  late Future<List<Produto>> _produtosFuture; 

  @override
  void initState() {
    super.initState();
    _refreshProdutos();
  }

  void _refreshProdutos() {
    setState(() {
      // O getProdutos do Service já traz apenas itens com tipo="FARMACIA"
      _produtosFuture = Provider.of<EstoqueService>(context, listen: false).getProdutos();
    });
  }

  // --- MODAL 1: CRIAR NOVO PRODUTO ---
  Future<void> _showAddProdutoDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _minimoController = TextEditingController(text: '0');
    final _valorController = TextEditingController(text: '0.00');
    UnidadeMedida _unidadeSelecionada = UnidadeMedida.UNIDADE;
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Novo Produto (Farmácia)'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nome do Medicamento/Insumo*'),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 10),
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
                      TextFormField(
                        controller: _valorController,
                        decoration: const InputDecoration(labelText: 'Preço Estimado (R\$)*'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (double.tryParse(v!.replaceAll(',', '.')) ?? -1) < 0 ? 'Inválido' : null,
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
                          unidade: _unidadeSelecionada.name,
                          estoqueMinimo: int.parse(_minimoController.text),
                          valor: double.parse(_valorController.text.replaceAll(',', '.')),
                          // O Service já força "FARMACIA" internamente
                        );
                        if (mounted) Navigator.of(context).pop();
                        _refreshProdutos();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                        if (mounted) setModalState(() => _isSaving = false);
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
  
  // --- MODAL 2: DAR ENTRADA EM PRODUTO ---
  Future<void> _showAddEntradaDialog(Produto produto) async { 
    final _formKey = GlobalKey<FormState>();
    final _qtdController = TextEditingController();
    final _loteController = TextEditingController();
    final _validadeController = TextEditingController(); 
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Entrada: ${produto.nome}'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _qtdController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Quantidade a Adicionar*'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0 ? 'Inválido' : null,
                      ),
                      TextFormField(
                        controller: _loteController,
                        decoration: const InputDecoration(labelText: 'Lote (Opcional)'),
                      ),
                      TextFormField(
                        controller: _validadeController,
                        decoration: const InputDecoration(labelText: 'Validade (AAAA-MM-DD)', hintText: '2025-12-31'),
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
                        if (mounted) Navigator.of(context).pop();
                        _refreshProdutos();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                         if (mounted) setModalState(() => _isSaving = false);
                      }
                    }
                  },
                  child: _isSaving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Confirmar'),
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
      // Usando List<Produto> real
      body: FutureBuilder<List<Produto>>(
        future: _produtosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum medicamento/insumo cadastrado.'));
          }

          final produtos = snapshot.data!;
          
          return ListView.builder(
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];

              // --- REMOVIDO O BLOCO DE FILTRO ERRADO QUE ESTAVA AQUI ---
              // A lista 'produtos' já veio filtrada do Service.
              
              final estoqueAtual = produto.estoque;
              final estoqueMinimo = produto.estoqueMinimo;
              
              final bool estoqueBaixo = estoqueMinimo > 0 && estoqueAtual <= estoqueMinimo;
              
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
                  title: Text(produto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Exibe a unidade (como é String vinda do JSON, não precisa de .name)
                        Text('Estoque: $estoqueAtual ${produto.unidadeMedida}'), 
                        if (estoqueBaixo)
                          Text('Estoque Baixo! Mínimo: $estoqueMinimo', style: TextStyle(color: Colors.red[800], fontSize: 12)),
                    ],
                  ), 
                  
                  trailing: ElevatedButton(
                    child: const Text('Entrada'),
                    onPressed: () => _showAddEntradaDialog(produto),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProdutoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Medicamento',
      ),
    );
  }
}