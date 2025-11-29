// lib/financeiro_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'impressoes_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // Aqui usamos o R$ com barra invertida para garantir
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  double _totalEntradasDia = 0.0;
  double _totalSaidasDia = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FinanceiroService>(context, listen: false).verificarStatusCaixa();
    });
    _refreshTransacoes();
  }

  void _refreshTransacoes() {
    setState(() {
      _transacoesFuture = Provider.of<FinanceiroService>(context, listen: false).getTransacoes();
    });
  }

  // --- MODAL DE ABRIR CAIXA ---
  void _showAbrirCaixaDialog() {
    final valorController = TextEditingController(text: '0,00');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Abrir Caixa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Informe o saldo inicial em dinheiro na gaveta:"),
            const SizedBox(height: 10),
            TextField(
              controller: valorController,
              keyboardType: TextInputType.number,
              // CORREÇÃO AQUI: R\$
              decoration: const InputDecoration(labelText: "Saldo Inicial (R\$)", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              try {
                await Provider.of<FinanceiroService>(context, listen: false).abrirCaixa(val);
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
              }
            },
            child: const Text("ABRIR CAIXA"),
          )
        ],
      ),
    );
  }

  // --- MODAL DE FECHAR CAIXA ---
  void _showFecharCaixaDialog(double saldoFinalEstimado) {
    final valorController = TextEditingController(text: saldoFinalEstimado.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fechar Caixa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Confira o dinheiro físico. O sistema calculou:"),
            // Aqui usamos interpolação ($) e o cifrão escapado (\$)
            Text("R\$ ${saldoFinalEstimado.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: valorController,
              keyboardType: TextInputType.number,
              // CORREÇÃO AQUI: R\$
              decoration: const InputDecoration(labelText: "Saldo Final Real (R\$)", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final val = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              try {
                await Provider.of<FinanceiroService>(context, listen: false).fecharCaixa(val);
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
              }
            },
            child: const Text("FECHAR CAIXA"),
          )
        ],
      ),
    );
  }

  // --- MODAL DE ADICIONAR TRANSAÇÃO ---
  Future<void> _showAddTransacaoDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _descController = TextEditingController();
    final _valorController = TextEditingController();
    String _tipoSelecionado = 'DESPESA';
    CategoriaFinanceira? _catSelecionada;
    Paciente? _pacienteSelecionado;
    DateTime _dataVenc = DateTime.now();

    bool _repetir = false;
    int _qtdParcelas = 2; 

    List<CategoriaFinanceira> _categorias = [];
    List<Paciente> _pacientes = [];
    
    try {
        final financeiroService = Provider.of<FinanceiroService>(context, listen: false);
        final pacienteService = Provider.of<PacienteService>(context, listen: false);
        _categorias = await financeiroService.getCategorias();
        _pacientes = await pacienteService.getPacientes();
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool _isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final categoriasFiltradas = _categorias.where((c) => c.tipo == _tipoSelecionado).toList();

            return AlertDialog(
              title: const Text('Lançar Transação'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: RadioListTile(title: const Text("Despesa", style: TextStyle(fontSize: 14)), value: 'DESPESA', groupValue: _tipoSelecionado, onChanged: (v) => setModalState(() => _tipoSelecionado = v!))),
                            Expanded(child: RadioListTile(title: const Text("Receita", style: TextStyle(fontSize: 14)), value: 'RECEITA', groupValue: _tipoSelecionado, onChanged: (v) => setModalState(() => _tipoSelecionado = v!))),
                          ],
                        ),
                        
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Descrição*'),
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                        TextFormField(
                          controller: _valorController,
                          // CORREÇÃO AQUI: R\$
                          decoration: const InputDecoration(labelText: 'Valor (R\$)*'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '0') ?? 0) <= 0 ? 'Inválido' : null,
                        ),
                        DropdownButtonFormField<CategoriaFinanceira>(
                          value: _catSelecionada,
                          hint: const Text('Categoria*'),
                          isExpanded: true,
                          items: categoriasFiltradas.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.nome))).toList(),
                          onChanged: (value) => setModalState(() => _catSelecionada = value),
                          validator: (v) => v == null ? 'Obrigatório' : null,
                        ),
                        if (_tipoSelecionado == 'RECEITA')
                          DropdownButtonFormField<Paciente>(
                            value: _pacienteSelecionado,
                            hint: const Text('Paciente (Opcional)'),
                            isExpanded: true,
                            items: _pacientes.map((pac) => DropdownMenuItem(value: pac, child: Text(pac.nomeCompleto))).toList(),
                            onChanged: (value) => setModalState(() => _pacienteSelecionado = value),
                          ),
                        
                        const Divider(),
                        SwitchListTile(
                          title: const Text("Repetir (Parcelar/Mensalidade)?"),
                          value: _repetir,
                          onChanged: (val) => setModalState(() => _repetir = val),
                        ),
                        if (_repetir)
                          Row(
                            children: [
                              const Text("Repetir por: "),
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  initialValue: _qtdParcelas.toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _qtdParcelas = int.tryParse(v) ?? 1,
                                ),
                              ),
                              const Text(" meses"),
                            ],
                          )
                      ],
                    ),
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
                          valor: double.parse(_valorController.text.replaceAll(',', '.')),
                          tipo: _tipoSelecionado,
                          dataVencimento: _dataVenc,
                          categoriaId: _catSelecionada!.id,
                          pacienteId: _pacienteSelecionado?.id,
                          repetir: _repetir,
                          parcelas: _qtdParcelas,
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

  // --- PAINEL DO CAIXA ---
  Widget _buildPainelCaixa(FinanceiroService service) {
    final caixa = service.caixaAtual;
    final aberto = service.isCaixaAberto;
    
    double saldoAtual = 0;
    if (aberto) {
      saldoAtual = caixa!.saldoInicial + _totalEntradasDia - _totalSaidasDia;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: aberto ? [Colors.teal, Colors.tealAccent.shade700] : [Colors.grey.shade700, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                aberto ? "CAIXA ABERTO" : "CAIXA FECHADO",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
              ),
              Icon(aberto ? Icons.lock_open : Icons.lock, color: Colors.white),
            ],
          ),
          const SizedBox(height: 15),
          if (aberto) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 _itemResumo("Saldo Inicial", caixa!.saldoInicial),
                 _itemResumo("Entradas (Hoje)", _totalEntradasDia, color: Colors.greenAccent),
                 _itemResumo("Saídas (Hoje)", _totalSaidasDia, color: Colors.redAccent),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Saldo em Caixa", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_currencyFormat.format(saldoAtual), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                  onPressed: () => _showFecharCaixaDialog(saldoAtual), 
                  child: const Text("FECHAR CAIXA"),
                )
              ],
            )
          ] else ...[
             const Center(child: Text("Abra o caixa para iniciar as operações do dia.", style: TextStyle(color: Colors.white70))),
             const SizedBox(height: 15),
             Center(
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                 onPressed: _showAbrirCaixaDialog, 
                 child: const Text("ABRIR CAIXA AGORA"),
               ),
             )
          ]
        ],
      ),
    );
  }

  Widget _itemResumo(String label, double valor, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(_currencyFormat.format(valor), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeiroService = Provider.of<FinanceiroService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Financeira'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Relatório', onPressed: _exportarRelatorio),
          IconButton(icon: const Icon(Icons.category_outlined), tooltip: 'Categorias', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CategoriasScreen()))),
        ],
      ),
      body: Column(
        children: [
          _buildPainelCaixa(financeiroService),
          Expanded(
            child: FutureBuilder<List<TransacaoFinanceira>>(
              future: _transacoesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final transacoes = snapshot.data ?? [];
                
                if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    double ent = 0;
                    double sai = 0;
                    final hoje = DateTime.now();
                    
                    for (var t in transacoes) {
                      if (t.dataPagamento != null) {
                        final p = t.dataPagamento!;
                        if (p.year == hoje.year && p.month == hoje.month && p.day == hoje.day) {
                          if (t.tipo == 'RECEITA') ent += t.valor;
                          if (t.tipo == 'DESPESA') sai += t.valor;
                        }
                      }
                    }
                    if (ent != _totalEntradasDia || sai != _totalSaidasDia) {
                      setState(() {
                        _totalEntradasDia = ent;
                        _totalSaidasDia = sai;
                      });
                    }
                  });
                }

                if (transacoes.isEmpty) return const Center(child: Text("Sem lançamentos recentes."));

                return ListView.builder(
                  itemCount: transacoes.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final trans = transacoes[index];
                    final bool isPago = trans.dataPagamento != null;
                    final bool isReceita = trans.tipo == 'RECEITA';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPago ? Colors.grey[300] : (isReceita ? Colors.green[50] : Colors.red[50]),
                          child: Icon(
                            isReceita ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isPago ? Colors.grey : (isReceita ? Colors.green : Colors.red),
                          ),
                        ),
                        title: Text(trans.descricao, style: TextStyle(decoration: isPago ? TextDecoration.lineThrough : null, color: isPago ? Colors.grey : Colors.black)),
                        subtitle: Text('${trans.categoriaNome} • Venc: ${DateFormat('dd/MM').format(trans.dataVencimento)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(trans.valor), style: TextStyle(fontWeight: FontWeight.bold, color: isReceita ? Colors.green[700] : Colors.red[700])),
                            Text(isPago ? "PAGO" : "ABERTO", style: TextStyle(fontSize: 10, color: isPago ? Colors.green : Colors.orange)),
                          ],
                        ),
                        onTap: () => _showMarcarComoPagoDialog(trans),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: financeiroService.isCaixaAberto ? _showAddTransacaoDialog : null, 
        backgroundColor: financeiroService.isCaixaAberto ? Colors.teal : Colors.grey,
        icon: const Icon(Icons.add),
        label: const Text("NOVO LANÇAMENTO"),
      ),
    );
  }
  
  Future<void> _showMarcarComoPagoDialog(TransacaoFinanceira transacao) async {
      if (!Provider.of<FinanceiroService>(context, listen: false).isCaixaAberto) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abra o caixa primeiro!')));
        return;
      }
      
      if (transacao.dataPagamento != null) return;
      
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Pagamento"),
        content: Text("Confirmar ${transacao.tipo == 'RECEITA' ? 'recebimento' : 'pagamento'} de ${transacao.descricao}?"),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Não")),
          ElevatedButton(onPressed: () async {
             await Provider.of<FinanceiroService>(context, listen: false).marcarComoPaga(transacao.id);
             Navigator.pop(ctx);
             _refreshTransacoes();
          }, child: const Text("Sim"))
        ],
      ));
  }
  
  Future<void> _exportarRelatorio() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação de PDF indisponível na versão Web.')));
      return;
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      helpText: 'Selecione o Período do Relatório',
    );

    if (picked == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final impressoesService = Provider.of<ImpressoesService>(context, listen: false);
      final pdfBytes = await impressoesService.gerarRelatorioFinanceiro(inicio: picked.start, fim: picked.end);

      Navigator.of(context).pop(); 

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/relatorio_financeiro.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      await OpenFile.open(filePath);

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }
}