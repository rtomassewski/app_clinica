// lib/financeiro_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'impressoes_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Para checar se é web
import 'financeiro_service.dart';
import 'paciente_service.dart'; 
import 'gestao_service.dart'; 
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
    final _formKey = GlobalKey<FormState>();
    final _descController = TextEditingController();
    final _valorController = TextEditingController();
    String _tipoSelecionado = 'DESPESA';
    CategoriaFinanceira? _catSelecionada;
    Paciente? _pacienteSelecionado;
    DateTime _dataVenc = DateTime.now();

    List<CategoriaFinanceira> _categorias = [];
    List<Paciente> _pacientes = [];
    String? _erroLoading;
    bool _isLoadingDados = true;

    Future<void> _loadModalData() async {
      try {
        final financeiroService = Provider.of<FinanceiroService>(context, listen: false);
        final pacienteService = Provider.of<PacienteService>(context, listen: false);
        
        final catFuture = financeiroService.getCategorias();
        final pacFuture = pacienteService.getPacientes();

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
            
            if (_isLoadingDados) {
              _loadModalData().then((_) {
                setModalState(() {
                  _isLoadingDados = false;
                });
              });
            }

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
                                DropdownButtonFormField<String>(
                                  value: _tipoSelecionado,
                                  items: const [
                                    DropdownMenuItem(value: 'DESPESA', child: Text('Despesa')),
                                    DropdownMenuItem(value: 'RECEITA', child: Text('Receita')),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tipoSelecionado = value!;
                                      _catSelecionada = null;
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
                                DropdownButtonFormField<CategoriaFinanceira>(
                                  value: _catSelecionada,
                                  hint: const Text('Categoria*'),
                                  items: categoriasFiltradas.map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat.nome));
                                  }).toList(),
                                  onChanged: (value) => setModalState(() => _catSelecionada = value),
                                  validator: (v) => v == null ? 'Obrigatório' : null,
                                ),
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
                          dataVencimento: _dataVenc,
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
        
        // --- BOTÕES DO APPBAR ---
        actions: [
          // 1. Botão de Exportar Relatório (NOVO)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar Relatório',
            onPressed: _exportarRelatorio,
          ),
          // 2. Botão de Gerenciar Categorias
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Gerenciar Categorias',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriasScreen(),
                ),
              );
            },
          ),
        ],
        // --- FIM DOS BOTÕES ---
      ),
      
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

  // --- MÉTODO DE EXPORTAÇÃO (Chamado pelo botão no AppBar) ---
  Future<void> _exportarRelatorio() async {
    // Se estiver na web, mostra aviso (pois o path_provider não funciona igual)
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportação de PDF indisponível na versão Web.')),
      );
      return;
    }

    // 1. Seleciona o intervalo de datas
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      helpText: 'Selecione o Período do Relatório',
    );

    if (picked == null) return;

    // 2. Mostra Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 3. Chama o serviço
      final impressoesService = Provider.of<ImpressoesService>(context, listen: false);
      final pdfBytes = await impressoesService.gerarRelatorioFinanceiro(
        inicio: picked.start,
        fim: picked.end,
      );

      Navigator.of(context).pop(); // Fecha Loading

      // 4. Salva e Abre (Lógica NATIVA - Windows/Android)
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/relatorio_financeiro.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      await OpenFile.open(filePath);

    } catch (e) {
      // Fecha o loading se ainda estiver aberto e der erro
      if (mounted && Navigator.canPop(context)) {
         Navigator.of(context).pop(); 
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }
}