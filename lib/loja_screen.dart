import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// Importe seus services (auth, paciente, loja_service se criar separado)

class LojaScreen extends StatefulWidget {
  const LojaScreen({Key? key}) : super(key: key);

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Carrinho de compras
  List<Map<String, dynamic>> _carrinho = [];
  double get _totalCarrinho => _carrinho.fold(0, (sum, item) => sum + (item['produto'].valor * item['qtd']));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    return Column(
      children: [
        // 1. Selecionar Paciente (Dropdown simulado)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(child: ListTile(title: Text("Selecionar Paciente"), trailing: Icon(Icons.arrow_drop_down))),
        ),
        
        // 2. Lista de Produtos Disponíveis para adicionar ao carrinho
        Expanded(
          child: ListView(
            children: [
              _produtoItemVenda("Refrigerante", 5.00),
              _produtoItemVenda("Salgado", 6.50),
              _produtoItemVenda("Kit Higiene", 15.00),
            ],
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
                onPressed: () {
                  // Lógica de finalizar venda chamando API
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Venda realizada! Saldo debitado.")));
                  setState(() => _carrinho.clear());
                },
                child: const Text("FINALIZAR"),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _produtoItemVenda(String nome, double preco) {
    return ListTile(
      title: Text(nome),
      subtitle: Text("R\$ ${preco.toStringAsFixed(2)}"),
      trailing: IconButton(
        icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
        onPressed: () {
          // Adiciona ao carrinho (Simulação)
          setState(() {
            // Em produção você usaria objetos reais
            // _carrinho.add({'produto': ..., 'qtd': 1}); 
          });
        },
      ),
    );
  }

  // --- ABA 2: GERENCIAR PRODUTOS ---
  Widget _buildAbaProdutos() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () {
             // Abrir Dialog para cadastrar novo produto
          },
          icon: const Icon(Icons.add),
          label: const Text("Cadastrar Novo Produto"),
        ),
        const Divider(),
        const ListTile(
          title: Text("Coca-Cola Lata"),
          subtitle: Text("Estoque: 45 | R\$ 5,00"),
          trailing: Icon(Icons.edit),
        ),
        // ... Lista vinda da API ...
      ],
    );
  }
}