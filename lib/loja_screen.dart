// lib/loja_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart'; // Descomente se precisar formatar datas

import 'loja_service.dart'; // Traz: Produto, LojaService

// Traz: Paciente, PacienteService e o enum StatusPaciente REAL.
// Ocultamos apenas o Produto para não dar conflito.
import 'paciente_service.dart' hide Produto; 

// REMOVIDO: enum StatusPaciente { ... } 
// (Não redefina! Use o que vem do import acima)

class LojaScreen extends StatefulWidget {
  const LojaScreen({super.key});

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Map<String, dynamic>> _carrinho = [];
  int? _pacienteSelecionadoId;
  
  double get _totalCarrinho => _carrinho.fold(0, (sum, item) => sum + (item['produto'].valor * item['qtd']));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LojaService>(context, listen: false).fetchProdutos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Loja & Cantina"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "PDV (Venda)", icon: Icon(Icons.point_of_sale)),
            Tab(text: "Produtos", icon: Icon(Icons.inventory)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaVenda(),
          _buildAbaProdutos(),
        ],
      ),
    );
  }

  // --- ABA 1: VENDA (PDV) ---
  Widget _buildAbaVenda() {
    final pacienteService = Provider.of<PacienteService>(context, listen: false);

    return FutureBuilder<List<Paciente>>(
      future: pacienteService.getPacientes() as Future<List<Paciente>>?, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Nenhum paciente encontrado."));
        }

        final pacientes = snapshot.data!;
        
        // --- CORREÇÃO DO FALLBACK ---
        final pacienteAtual = pacientes.firstWhere(
            (p) => p.id == _pacienteSelecionadoId,
            orElse: () => Paciente(
              id: 0, 
              nomeCompleto: "Nenhum Selecionado", 
              saldo: 0.0,
              // Usa o enum que veio do import 'paciente_service.dart'
              status: StatusPaciente.ATIVO.name, 
              // CPF REMOVIDO (Não existe no construtor segundo o log)
              // nomeSocial: null, (Opcional, não precisa passar)
            ),
        );
        // -----------------------------

        return Column(
          children: [
            // 1. Selecionar Paciente
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: "Paciente para Venda",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                  ),
                  value: _pacienteSelecionadoId,
                  items: pacientes.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text("${p.nomeCompleto} (Crédito: R\$ ${p.saldo.toStringAsFixed(2)})"), 
                  )).toList(),
                  onChanged: (novoId) {
                    setState(() {
                      _pacienteSelecionadoId = novoId;
                    });
                  },
                ),
              ),
            ),
            
            // 2. Lista de Produtos Disponíveis
            Expanded(
              child: Consumer<LojaService>(
                builder: (context, lojaService, child) {
                  final produtos = lojaService.produtosLoja.where((p) => p.ativo).toList();
                  return ListView.builder(
                    itemCount: produtos.length,
                    itemBuilder: (context, index) {
                      final produto = produtos[index];
                      return _produtoItemVenda(produto); 
                    },
                  );
                },
              ),
            ),

            // 3. Resumo do Carrinho
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total: R\$ ${_totalCarrinho.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _pacienteSelecionadoId == null || _carrinho.isEmpty ? null : () {
                      _finalizarVenda(context);
                    },
                    child: const Text("FINALIZAR"),
                  )
                ],
              ),
            )
          ],
        );
      },
    );
  }

  void _finalizarVenda(BuildContext context) async {
      try {
        final lojaService = Provider.of<LojaService>(context, listen: false);
        // Prepara os itens para o formato que o backend espera
        final itensVenda = _carrinho.map((item) => {
          "produtoId": item['produto'].id,
          "qtd": item['qtd']
        }).toList();

        await lojaService.realizarVenda(
          pacienteId: _pacienteSelecionadoId!, 
          itens: itensVenda
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Venda realizada com sucesso!")));
        setState(() {
          _carrinho.clear();
          _pacienteSelecionadoId = null;
        });
        
        // Atualiza saldos (recarregando pacientes se necessário)
        // Provider.of<PacienteService>(context, listen: false).fetchPacientes(); // Se existir esse método
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro na venda: $e"), backgroundColor: Colors.red));
      }
  }

  Widget _produtoItemVenda(Produto produto) {
    void _adicionarAoCarrinho() {
      setState(() {
        final existingItemIndex = _carrinho.indexWhere((item) => item['produto'].id == produto.id);
        if (existingItemIndex != -1) {
          _carrinho[existingItemIndex]['qtd'] += 1;
        } else {
          _carrinho.add({'produto': produto, 'qtd': 1});
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${produto.nome} adicionado ao carrinho.'), duration: const Duration(milliseconds: 500))
      );
    }

    return ListTile(
      title: Text(produto.nome),
      subtitle: Text("R\$ ${produto.valor.toStringAsFixed(2)} | Estoque: ${produto.estoque}"),
      trailing: IconButton(
        icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
        onPressed: produto.estoque > 0 ? _adicionarAoCarrinho : null,
      ),
    );
  }

  // --- ABA 2: GERENCIAR PRODUTOS ---
  Widget _buildAbaProdutos() {
    return Consumer<LojaService>(
      builder: (context, lojaService, child) {
        final produtos = lojaService.produtosLoja;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditProdutoDialog(context),
                icon: const Icon(Icons.add),
                label: const Text("Cadastrar Novo Produto"),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  final produto = produtos[index];
                  return ListTile(
                    title: Text(produto.nome, style: TextStyle(fontWeight: FontWeight.bold, color: produto.ativo ? Colors.black : Colors.grey)),
                    subtitle: Text("Estoque: ${produto.estoque} | Preço: R\$ ${produto.valor.toStringAsFixed(2)}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: () => _showAddEditProdutoDialog(context, produtoParaEditar: produto),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- MODAL DE CRUD DE PRODUTOS ---
  void _showAddEditProdutoDialog(BuildContext context, {Produto? produtoParaEditar}) {
    final isEditing = produtoParaEditar != null;
    final _formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: produtoParaEditar?.nome);
    final valorController = TextEditingController(text: produtoParaEditar?.valor.toStringAsFixed(2) ?? '0.00');
    final minController = TextEditingController(text: produtoParaEditar?.estoqueMinimo.toString() ?? '0');
    
    String unidadeSelecionada = produtoParaEditar?.unidadeMedida ?? 'UNIDADE';
    
    showDialog(
      context: context,
      builder: (ctx) {
        // ADICIONADO: StatefulBuilder para atualizar o Dropdown visualmente
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEditing ? "Editar Produto: ${produtoParaEditar!.nome}" : "Novo Produto"),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomeController,
                        decoration: const InputDecoration(labelText: 'Nome do Produto'),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                      TextFormField(
                        controller: valorController,
                        decoration: const InputDecoration(labelText: 'Preço (R\$)*'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (double.tryParse(v!.replaceAll(',', '.')) ?? 0) < 0 ? 'Preço inválido' : null,
                      ),
                      TextFormField(
                        controller: minController,
                        decoration: const InputDecoration(labelText: 'Estoque Mínimo'),
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<String>(
                        value: unidadeSelecionada,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: ['UNIDADE', 'CAIXA', 'FRASCO', 'ML']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                           // Usa setModalState para atualizar a tela do modal
                           setModalState(() => unidadeSelecionada = v!);
                        },
                      ),
                      if (isEditing) 
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text("Estoque Atual: ${produtoParaEditar!.estoque}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final lojaService = Provider.of<LojaService>(context, listen: false);
                      try {
                        await lojaService.saveProduto(
                            id: isEditing ? produtoParaEditar!.id : null, 
                            nome: nomeController.text,
                            valor: double.parse(valorController.text.replaceAll(',', '.')),
                            unidade: unidadeSelecionada,
                            estoqueMinimo: int.parse(minController.text)
                        );
                        
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? "Produto atualizado!" : "Produto criado!")));
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: Text(isEditing ? "Salvar Alterações" : "Criar Produto"),
                )
              ],
            );
          }
        );
      },
    );
  }}