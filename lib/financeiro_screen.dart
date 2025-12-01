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
import 'auth_service.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({Key? key}) : super(key: key);

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  // Mudamos de Future para Lista em memória para facilitar o CustomScrollView
  List<TransacaoFinanceira> _listaTransacoes = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  // Totais do CAIXA (Operacional - Hoje)
  double _caixaEntradasHoje = 0.0;
  double _caixaSaidasHoje = 0.0;

  // Filtros
  DateTimeRange? _filtroPeriodo;
  String _filtroTipo = 'TODOS'; 
  String _filtroStatus = 'TODOS'; 

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filtroPeriodo = DateTimeRange(
      start: DateTime(now.year, now.month, 1), 
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59)
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FinanceiroService>(context, listen: false).verificarStatusCaixa();
    });
    _carregarDados();
  }

  void _carregarDados() {
    setState(() => _isLoading = true);
    Provider.of<FinanceiroService>(context, listen: false)
        .getTransacoes()
        .then((lista) {
          if (mounted) {
            setState(() {
              _listaTransacoes = lista;
              _isLoading = false;
            });
            _calcularCaixaHoje(lista);
          }
        })
        .catchError((e) {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  void _calcularCaixaHoje(List<TransacaoFinanceira> transacoes) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final meuId = authService.usuarioLogado?.id;
    final bool isChefia = authService.isAdmin || authService.isGestor;

    double ent = 0;
    double sai = 0;
    final hoje = DateTime.now();

    for (var t in transacoes) {
      if (t.dataPagamento != null) {
        final p = t.dataPagamento!.toLocal();
        bool isHoje = p.year == hoje.year && p.month == hoje.month && p.day == hoje.day;
        
        bool devoSomar = isChefia 
            ? true 
            : (t.usuarioBaixaId == meuId || t.usuarioBaixaId == null);

        if (isHoje && devoSomar) {
          if (t.tipo == 'RECEITA') ent += t.valor;
          if (t.tipo == 'DESPESA') sai += t.valor;
        }
      }
    }
    
    setState(() {
      _caixaEntradasHoje = ent;
      _caixaSaidasHoje = sai;
    });
  }

  // --- FILTRAGEM ---
  List<TransacaoFinanceira> _aplicarFiltros() {
    return _listaTransacoes.where((t) {
      final dataRef = t.dataVencimento; 
      bool dataOk = true;
      if (_filtroPeriodo != null) {
        dataOk = dataRef.isAfter(_filtroPeriodo!.start.subtract(const Duration(days: 1))) && 
                 dataRef.isBefore(_filtroPeriodo!.end.add(const Duration(days: 1)));
      }
      bool tipoOk = _filtroTipo == 'TODOS' || t.tipo == _filtroTipo;
      bool statusOk = true;
      if (_filtroStatus == 'PAGO') statusOk = t.dataPagamento != null;
      if (_filtroStatus == 'ABERTO') statusOk = t.dataPagamento == null;

      return dataOk && tipoOk && statusOk;
    }).toList();
  }

  // --- UI CORRIGIDA (CustomScrollView) ---
  @override
  Widget build(BuildContext context) {
    final financeiroService = Provider.of<FinanceiroService>(context);
    final authService = Provider.of<AuthService>(context);
    
    // REGRA DE PERMISSÃO: Admin/Gestor pode lançar sem caixa aberto
    final bool podeMovimentar = financeiroService.isCaixaAberto || authService.isAdmin || authService.isGestor;

    // Aplica filtros na lista em memória
    final listaFiltrada = _aplicarFiltros();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Financeira'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportarRelatorio),
          IconButton(icon: const Icon(Icons.category_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CategoriasScreen()))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _carregarDados(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. O Painel do Caixa (Agora rola junto com a tela)
            SliverToBoxAdapter(
              child: _buildPainelCaixa(financeiroService),
            ),

            // 2. Os Filtros
            SliverToBoxAdapter(
              child: _buildFiltros(),
            ),

            // 3. O Resumo dos Filtros
            SliverToBoxAdapter(
              child: _buildResumoFiltro(listaFiltrada),
            ),

            // 4. A Lista de Transações (Expandida)
            if (_isLoading)
               const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (listaFiltrada.isEmpty)
               const SliverFillRemaining(child: Center(child: Text("Nenhuma transação encontrada.", style: TextStyle(color: Colors.grey))))
            else
               SliverList(
                 delegate: SliverChildBuilderDelegate(
                   (context, index) {
                     final trans = listaFiltrada[index];
                     return _buildTransacaoCard(trans, podeMovimentar);
                   },
                   childCount: listaFiltrada.length,
                 ),
               ),
             
             // Espaço extra no final para o botão não cobrir o último item
             const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // CORREÇÃO: Libera botão se for Admin/Gestor OU Caixa Aberto
        onPressed: podeMovimentar ? _showAddTransacaoDialog : null, 
        backgroundColor: podeMovimentar ? Colors.teal : Colors.grey,
        icon: const Icon(Icons.add),
        label: const Text("NOVO LANÇAMENTO"),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildTransacaoCard(TransacaoFinanceira trans, bool podeMovimentar) {
    final bool isPago = trans.dataPagamento != null;
    final bool isReceita = trans.tipo == 'RECEITA';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        onTap: () => _showMarcarComoPagoDialog(trans, podeMovimentar),
      ),
    );
  }

  Widget _buildPainelCaixa(FinanceiroService service) {
    final caixa = service.caixaAtual;
    final aberto = service.isCaixaAberto;
    
    double saldoAtual = 0;
    if (aberto) {
      saldoAtual = caixa!.saldoInicial + _caixaEntradasHoje - _caixaSaidasHoje;
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
                aberto ? "CAIXA DO DIA" : "CAIXA FECHADO",
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
                 _itemResumo("Entradas (Hoje)", _caixaEntradasHoje, color: Colors.greenAccent),
                 _itemResumo("Saídas (Hoje)", _caixaSaidasHoje, color: Colors.redAccent),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Saldo Físico", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_currencyFormat.format(saldoAtual), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                  onPressed: () => _showFecharCaixaDialog(saldoAtual), 
                  child: const Text("FECHAR"),
                )
              ],
            )
          ] else ...[
             const Center(child: Text("O caixa está fechado.", style: TextStyle(color: Colors.white70))),
             const SizedBox(height: 10),
             Center(
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                 onPressed: _showAbrirCaixaDialog, 
                 child: const Text("ABRIR CAIXA"),
               ),
             )
          ]
        ],
      ),
    );
  }

  // --- FILTROS UI ---
  Widget _buildFiltros() {
    final formatData = DateFormat('dd/MM/yyyy');
    String textoData = _filtroPeriodo == null 
        ? "Todo o Período" 
        : "${formatData.format(_filtroPeriodo!.start)} até ${formatData.format(_filtroPeriodo!.end)}";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 1,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Row(
          children: [
            const Icon(Icons.filter_list, color: Colors.teal),
            const SizedBox(width: 10),
            Text("Filtros: $textoData", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(textoData),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _filtroPeriodo,
                    );
                    if (picked != null) setState(() => _filtroPeriodo = picked);
                  },
                ),
                const SizedBox(height: 10),
                const Text("Tipo:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', 'TODOS', _filtroTipo, (v) => setState(() => _filtroTipo = v)),
                      _buildFilterChip('Receitas', 'RECEITA', _filtroTipo, (v) => setState(() => _filtroTipo = v), color: Colors.green),
                      _buildFilterChip('Despesas', 'DESPESA', _filtroTipo, (v) => setState(() => _filtroTipo = v), color: Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Status:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', 'TODOS', _filtroStatus, (v) => setState(() => _filtroStatus = v)),
                      _buildFilterChip('Pagos', 'PAGO', _filtroStatus, (v) => setState(() => _filtroStatus = v), color: Colors.teal),
                      _buildFilterChip('Abertos', 'ABERTO', _filtroStatus, (v) => setState(() => _filtroStatus = v), color: Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelected, {Color? color}) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(value),
        checkmarkColor: Colors.white,
        selectedColor: color ?? Colors.grey[700],
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontSize: 12),
      ),
    );
  }

  Widget _buildResumoFiltro(List<TransacaoFinanceira> listaFiltrada) {
    double receita = 0;
    double despesa = 0;
    for (var t in listaFiltrada) {
      if (t.tipo == 'RECEITA') receita += t.valor;
      if (t.tipo == 'DESPESA') despesa += t.valor;
    }
    double saldo = receita - despesa;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resumoItem("Receitas", receita, Colors.green[800]!),
          _resumoItem("Despesas", despesa, Colors.red[800]!),
          _resumoItem("Saldo", saldo, saldo >= 0 ? Colors.blue[800]! : Colors.red[800]!),
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

  Widget _resumoItem(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(_currencyFormat.format(val), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }

  // --- DIALOGS (Modais) ---
  
  void _showAbrirCaixaDialog() {
    final valorController = TextEditingController(text: '0,00');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Abrir Caixa"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Saldo inicial em dinheiro:"), const SizedBox(height: 10),
        TextField(controller: valorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Valor (R\$)", border: OutlineInputBorder()))
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () async {
           final val = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
           await Provider.of<FinanceiroService>(context, listen: false).abrirCaixa(val);
           Navigator.pop(ctx);
        }, child: const Text("ABRIR"))
      ],
    ));
  }

  void _showFecharCaixaDialog(double saldoFinalEstimado) {
    final valorController = TextEditingController(text: saldoFinalEstimado.toStringAsFixed(2));
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Fechar Caixa"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Conferência física. O sistema prevê:"),
        Text("R\$ ${saldoFinalEstimado.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 20),
        TextField(controller: valorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Saldo Real (R\$)", border: OutlineInputBorder()))
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
           final val = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
           await Provider.of<FinanceiroService>(context, listen: false).fecharCaixa(val);
           Navigator.pop(ctx);
        }, child: const Text("FECHAR CAIXA"))
      ],
    ));
  }

  Future<void> _showMarcarComoPagoDialog(TransacaoFinanceira transacao, bool podeMovimentar) async {
      // CORREÇÃO: Admin/Gestor pode pagar mesmo sem caixa aberto
      if (!podeMovimentar) {
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
             _carregarDados();
          }, child: const Text("Sim"))
        ],
      ));
  }

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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [Expanded(child: RadioListTile(title: const Text("Despesa"), value: 'DESPESA', groupValue: _tipoSelecionado, onChanged: (v) => setModalState(() => _tipoSelecionado = v!))), Expanded(child: RadioListTile(title: const Text("Receita"), value: 'RECEITA', groupValue: _tipoSelecionado, onChanged: (v) => setModalState(() => _tipoSelecionado = v!)))]),
                        TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição*'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null,),
                        TextFormField(controller: _valorController, decoration: const InputDecoration(labelText: 'Valor (R\$)*'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '0') ?? 0) <= 0 ? 'Inválido' : null,),
                        DropdownButtonFormField<CategoriaFinanceira>(value: _catSelecionada, hint: const Text('Categoria*'), isExpanded: true, items: categoriasFiltradas.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.nome))).toList(), onChanged: (value) => setModalState(() => _catSelecionada = value), validator: (v) => v == null ? 'Obrigatório' : null,),
                        if (_tipoSelecionado == 'RECEITA') DropdownButtonFormField<Paciente>(value: _pacienteSelecionado, hint: const Text('Paciente (Opcional)'), isExpanded: true, items: _pacientes.map((pac) => DropdownMenuItem(value: pac, child: Text(pac.nomeCompleto))).toList(), onChanged: (value) => setModalState(() => _pacienteSelecionado = value),),
                        const Divider(),
                        SwitchListTile(title: const Text("Repetir?"), value: _repetir, onChanged: (val) => setModalState(() => _repetir = val),),
                        if (_repetir) Row(children: [const Text("Qtd: "), SizedBox(width: 50, child: TextFormField(initialValue: _qtdParcelas.toString(), keyboardType: TextInputType.number, onChanged: (v) => _qtdParcelas = int.tryParse(v) ?? 1))]),
                    ]),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        await Provider.of<FinanceiroService>(context, listen: false).addTransacao(descricao: _descController.text, valor: double.parse(_valorController.text.replaceAll(',', '.')), tipo: _tipoSelecionado, dataVencimento: _dataVenc, categoriaId: _catSelecionada!.id, pacienteId: _pacienteSelecionado?.id, repetir: _repetir, parcelas: _qtdParcelas);
                        Navigator.pop(context);
                        _carregarDados();
                      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); }
                    }
                  }, child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportarRelatorio() async {
    if (kIsWeb) return;
    final DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: _filtroPeriodo ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()));
    if (picked == null) return;
    try {
      final pdfBytes = await Provider.of<ImpressoesService>(context, listen: false).gerarRelatorioFinanceiro(inicio: picked.start, fim: picked.end);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/relatorio_financeiro.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      await OpenFile.open(filePath);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); }
  }
}