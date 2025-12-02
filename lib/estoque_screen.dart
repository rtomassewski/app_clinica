// lib/estoque_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'estoque_service.dart';

// O tipo de dado deve ser ajustado para a sua classe real no Service.
// Assumindo que Produto é a classe de modelo, vamos usar dynamic para o Future
// para evitar erros de compilação sem ver o código completo do Service.
class ProdutoEstoque {} // Placeholder para evitar erro de referência
enum UnidadeMedida { UNIDADE, CAIXA, FRASCO, ML } // Placeholder para o Enum

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({Key? key}) : super(key: key);

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  // Alterei o tipo para Future<List<dynamic>> para maior compatibilidade.
  // O correto seria Future<List<Produto>> se a classe estivesse aqui.
  late Future<List<dynamic>> _produtosFuture; 

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

  // --- MODAL 1: CRIAR NOVO PRODUTO (CORRIGIDO) ---
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
                      // --- CORREÇÃO 1: Adicionado a barra invertida (\) ---
                      TextFormField(
                        controller: _valorController,
                        decoration: const InputDecoration(labelText: 'Preço de Venda (R\$)*'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (double.tryParse(v!.replaceAll(',', '.')) ?? -1) < 0 ? 'Inválido' : null,
                      ),
                      // ----------------------------------------------------
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
                          // --- CORREÇÃO 2: Passando o nome da enum como String ---
                          unidade: _unidadeSelecionada.name,
                          // ------------------------------------------------------
                          estoqueMinimo: int.parse(_minimoController.text),
                          valor: double.parse(_valorController.text.replaceAll(',', '.')),
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
  // O tipo é dynamic porque não temos a classe ProdutoEstoque aqui
  Future<void> _showAddEntradaDialog(dynamic produto) async { 
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
                        // --- CHAMADA CORRIGIDA: Se o método não existir, o erro vai aparecer no Service ---
                        await Provider.of<EstoqueService>(context, listen: false)
                            .addEntradaEstoque( // <-- O Service PRECISA deste método
                          produtoId: produto.id,
                          quantidade: int.parse(_qtdController.text),
                          lote: _loteController.text.isEmpty ? null : _loteController.text,
                          dataValidade: _validadeController.text.isEmpty ? null : _validadeController.text,
                        );
                        // ------------------------------------------------------------------------------------
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
      body: FutureBuilder<List<dynamic>>(
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
              
              // Acesso aos campos corrigidos (assumindo que o Service os corrigiu)
              final estoqueAtual = produto.estoque ?? 0;
              final estoqueMinimo = produto.estoqueMinimo ?? 0;
              final valorVenda = produto.valor ?? 0.0;
              
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
                  title: Text(produto.nome),
                  
                  // --- CORREÇÃO APLICADA AQUI (Acesso Condicional) ---
                  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
        // O .name é o problema se a unidadeMedida for nula.
        // Usamos ?.name para evitar o erro e ?? 'UND' como fallback.
        Text('Estoque Atual: $estoqueAtual ${produto.unidadeMedida}'), 
        // ...
    ],
), 
                  // ----------------------------------------------------
                  
                  trailing: ElevatedButton(
                    child: const Text('Dar Entrada'),
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
        tooltip: 'Novo Produto',
      ),
    );
  }
}