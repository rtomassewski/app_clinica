// lib/financeiro_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'financeiro_service.dart';
import 'paciente_service.dart'; // Para a lista de pacientes
import 'gestao_service.dart'; // Para o modelo 'Papel' (apenas para o tipo)
import 'categorias_screen.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({Key? key}) : super(key: key);

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  late Future<List<TransacaoFinanceira>> _transacoesFuture;
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _refreshTransacoes();
  }

  void _refreshTransacoes() {
    setState(() {
      _transacoesFuture =
          Provider.of<FinanceiroService>(context, listen: false).getTransacoes();
    });
  }

  // --- O MODAL DE ADICIONAR TRANSAÇÃO ---
  Future<void> _showAddTransacaoDialog() async {
    // Controladores do formulário
    final _formKey = GlobalKey<FormState>();
    final _descController = TextEditingController();
    final _valorController = TextEditingController();
    String _tipoSelecionado = 'DESPESA'; // Padrão
    CategoriaFinanceira? _catSelecionada;
    Paciente? _pacienteSelecionado; // Opcional
    DateTime _dataVenc = DateTime.now();

    // Dados para os dropdowns (buscados da API)
    List<CategoriaFinanceira> _categorias = [];
    List<Paciente> _pacientes = [];
    String? _erroLoading;
    bool _isLoadingDados = true;

    // Busca os dados para os dropdowns
    Future<void> _loadModalData() async {
      try {
        final financeiroService = Provider.of<FinanceiroService>(context, listen: false);
        final pacienteService = Provider.of<PacienteService>(context, listen: false);
        
        final catFuture = financeiroService.getCategorias();
        final pacFuture = pacienteService.getPacientes(); // (Este 'getPacientes' não está filtrado, mas serve)

        _categorias = await catFuture;
        _pacientes = await pacFuture;
      } catch (e) {
        _erroLoading = e.toString();
      }
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool _isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Carrega os dados na primeira vez
            if (_isLoadingDados) {
              _loadModalData().then((_) {
                setModalState(() {
                  _isLoadingDados = false;
                });
              });
            }

            // Filtra as categorias baseado no Tipo (Receita/Despesa)
            final categoriasFiltradas = _categorias
                .where((c) => c.tipo == _tipoSelecionado)
                .toList();

            return AlertDialog(
              title: const Text('Lançar Transação'),
              content: _isLoadingDados
                  ? const Center(child: CircularProgressIndicator())
                  : _erroLoading != null
                      ? Center(child: Text('Erro: $_erroLoading'))
                      : Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Seletor de Tipo
                                DropdownButtonFormField<String>(
                                  value: _tipoSelecionado,
                                  items: const [
                                    DropdownMenuItem(value: 'DESPESA', child: Text('Despesa')),
                                    DropdownMenuItem(value: 'RECEITA', child: Text('Receita')),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tipoSelecionado = value!;
                                      _catSelecionada = null; // Reseta a categoria
                                    });
                                  },
                                ),
                                TextFormField(
                                  controller: _descController,
                                  decoration: const InputDecoration(labelText: 'Descrição*'),
                                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                                ),
                                TextFormField(
                                  controller: _valorController,
                                  decoration: const InputDecoration(labelText: 'Valor (ex: 150.50)*'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => (double.tryParse(v ?? '0') ?? 0) <= 0 ? 'Inválido' : null,
                                ),
                                // Dropdown de Categorias (filtrado)
                                DropdownButtonFormField<CategoriaFinanceira>(
                                  value: _catSelecionada,
                                  hint: const Text('Categoria*'),
                                  items: categoriasFiltradas.map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat.nome));
                                  }).toList(),
                                  onChanged: (value) => setModalState(() => _catSelecionada = value),
                                  validator: (v) => v == null ? 'Obrigatório' : null,
                                ),
                                // Dropdown de Pacientes (Opcional, só para Receitas)
                                if (_tipoSelecionado == 'RECEITA')
                                  DropdownButtonFormField<Paciente>(
                                    value: _pacienteSelecionado,
                                    hint: const Text('Paciente (Opcional)'),
                                    items: _pacientes.map((pac) {
                                      return DropdownMenuItem(value: pac, child: Text(pac.nomeCompleto));
                                    }).toList(),
                                    onChanged: (value) => setModalState(() => _pacienteSelecionado = value),
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
                        await Provider.of<FinanceiroService>(context, listen: false).addTransacao(
                          descricao: _descController.text,
                          valor: double.parse(_valorController.text),
                          tipo: _tipoSelecionado,
                          dataVencimento: _dataVenc, // (Usando 'agora', TODO: Adicionar DatePicker)
                          categoriaId: _catSelecionada!.id,
                          pacienteId: _pacienteSelecionado?.id,
                        );
                        Navigator.of(context).pop();
                        _refreshTransacoes();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                        setModalState(() => _isSaving = false);
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
  
  // --- MODAL DE MARCAR COMO PAGO ---
  Future<void> _showMarcarComoPagoDialog(TransacaoFinanceira transacao) async {
    if (transacao.dataPagamento != null) {
      // Já está pago
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta transação já foi paga.')));
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Pagamento?'),
          content: Text('Deseja marcar "${transacao.descricao}" como PAGO agora?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Provider.of<FinanceiroService>(context, listen: false).marcarComoPaga(transacao.id);
                  Navigator.of(context).pop();
                  _refreshTransacoes();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Sim, Marcar Pago'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro (Caixa)'),
        
        // --- O BLOCO 'actions' FOI MOVIDO PARA CÁ ---
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Gerenciar Categorias',
            onPressed: () {
              // 3. Navega para a nova tela
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriasScreen(),
                ),
              );
            },
          ),
        ],
        // --- FIM DA CORREÇÃO ---
      ), // <-- O AppBar agora fecha aqui
      
      body: FutureBuilder<List<TransacaoFinanceira>>(
        future: _transacoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum lançamento financeiro.'));
          }

          final transacoes = snapshot.data!;
          return ListView.builder(
            itemCount: transacoes.length,
            itemBuilder: (context, index) {
              final trans = transacoes[index];
              final bool isPago = trans.dataPagamento != null;
              final bool isReceita = trans.tipo == 'RECEITA';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPago 
                        ? Colors.grey
                        : (isReceita ? Colors.green.shade100 : Colors.red.shade100),
                    child: Icon(
                      isReceita ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPago ? Colors.grey[600] : (isReceita ? Colors.green[800] : Colors.red[800]),
                    ),
                  ),
                  title: Text(trans.descricao),
                  subtitle: Text(
                    '${trans.categoriaNome} (${DateFormat('dd/MM/yy').format(trans.dataVencimento)})'
                    '${trans.pacienteNome != null ? '\nPaciente: ${trans.pacienteNome}' : ''}'
                  ),
                  isThreeLine: trans.pacienteNome != null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currencyFormat.format(trans.valor),
                        style: TextStyle(
                          color: isReceita ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPago ? 'PAGO' : 'PENDENTE',
                        style: TextStyle(
                          color: isPago ? Colors.grey : Colors.orange[800],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showMarcarComoPagoDialog(trans),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransacaoDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Lançamento',
      ),
    );
  }
}