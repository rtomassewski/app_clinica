// lib/financeiro_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

// Imports do seu projeto
import 'notificacao_service.dart';
import 'impressoes_service.dart';
import 'financeiro_service.dart';
import 'paciente_service.dart'; 
import 'gestao_service.dart'; 
import 'categorias_screen.dart';
import 'auth_service.dart';
import 'recibo_service.dart'; // <--- GARANTA QUE ESTE ARQUIVO EXISTE

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({Key? key}) : super(key: key);

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  List<TransacaoFinanceira> _listaTransacoes = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  // Totais do CAIXA
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

  @override
  Widget build(BuildContext context) {
    final financeiroService = Provider.of<FinanceiroService>(context);
    final authService = Provider.of<AuthService>(context);
    
    final bool podeMovimentar = financeiroService.isCaixaAberto || authService.isAdmin || authService.isGestor;

    final listaFiltrada = _aplicarFiltros();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Financeira'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportarRelatorio),
          IconButton(icon: const Icon(Icons.category_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CategoriasScreen()))),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Configurar Lembretes',
            onPressed: _showConfigNotificacao,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _carregarDados(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildPainelCaixa(financeiroService)),
            SliverToBoxAdapter(child: _buildFiltros()),
            SliverToBoxAdapter(child: _buildResumoFiltro(listaFiltrada)),

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
             
             const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: podeMovimentar ? () => _showAddEditTransacaoDialog() : null,
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
        
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currencyFormat.format(trans.valor), style: TextStyle(fontWeight: FontWeight.bold, color: isReceita ? Colors.green[700] : Colors.red[700])),
                Text(isPago ? "PAGO" : "ABERTO", style: TextStyle(fontSize: 10, color: isPago ? Colors.green : Colors.orange)),
              ],
            ),
            
            // --- NOVO: BOTÃO DE IMPRIMIR ---
            IconButton(
              icon: const Icon(Icons.print, color: Colors.blueGrey),
              tooltip: "Imprimir Comprovante",
              onPressed: () => _mostrarOpcoesImpressao(trans),
            ),
            // --------------------------------

            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'editar') {
                  _showAddEditTransacaoDialog(transacaoParaEditar: trans);
                } else if (value == 'excluir') {
                  _confirmarExclusao(trans.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'editar', child: Text("Editar")),
                const PopupMenuItem(value: 'excluir', child: Text("Excluir", style: TextStyle(color: Colors.red))),
              ],
            )
          ],
        ),
        onTap: () => _showMarcarComoPagoDialog(trans, podeMovimentar),
      ),
    );
  }

  // --- NOVO: MÉTODO PARA ESCOLHER TIPO DE IMPRESSÃO ---
  void _mostrarOpcoesImpressao(TransacaoFinanceira trans) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Imprimir Comprovante:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text("Térmica (Cupom)"),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ReciboService.imprimirRecibo(transacao: trans, isTermica: true);
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
                    icon: const Icon(Icons.description),
                    label: const Text("A4 (Padrão)"),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ReciboService.imprimirRecibo(transacao: trans, isTermica: false);
                    },
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPainelCaixa(FinanceiroService service) {
      final caixa = service.caixaAtual;
      final aberto = service.isCaixaAberto;
      double saldoAtual = 0;
      if (aberto) saldoAtual = caixa!.saldoInicial + _caixaEntradasHoje - _caixaSaidasHoje;

      return Container(
        width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: aberto ? [Colors.teal, Colors.tealAccent.shade700] : [Colors.grey.shade700, Colors.grey.shade900]), borderRadius: BorderRadius.circular(15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(aberto ? "CAIXA DO DIA" : "CAIXA FECHADO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Icon(aberto ? Icons.lock_open : Icons.lock, color: Colors.white)]),
            const SizedBox(height: 15),
            if (aberto) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_itemResumo("Saldo Inicial", caixa!.saldoInicial), _itemResumo("Entradas", _caixaEntradasHoje, color: Colors.greenAccent), _itemResumo("Saídas", _caixaSaidasHoje, color: Colors.redAccent)]),
              const Divider(color: Colors.white24, height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Saldo Físico", style: TextStyle(color: Colors.white70)), Text(_currencyFormat.format(saldoAtual), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))]), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal), onPressed: () => _showFecharCaixaDialog(saldoAtual), child: const Text("FECHAR"))])
            ] else ...[
               Center(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), onPressed: _showAbrirCaixaDialog, child: const Text("ABRIR CAIXA")))
            ]
        ]),
      );
  }

  Widget _buildFiltros() {
    final formatData = DateFormat('dd/MM/yyyy');
    String textoData = _filtroPeriodo == null ? "Todo o Período" : "${formatData.format(_filtroPeriodo!.start)} até ${formatData.format(_filtroPeriodo!.end)}";
    return Card(margin: const EdgeInsets.symmetric(horizontal: 16), child: ExpansionTile(title: Text("Filtros: $textoData"), children: [
        Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
            OutlinedButton.icon(icon: const Icon(Icons.calendar_today), label: Text(textoData), onPressed: () async {
                final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDateRange: _filtroPeriodo);
                if (picked != null) setState(() => _filtroPeriodo = picked);
            }),
             Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
               _buildFilterChip('TODOS', _filtroTipo, (v) => setState(() => _filtroTipo = v)),
               _buildFilterChip('RECEITA', _filtroTipo, (v) => setState(() => _filtroTipo = v)),
               _buildFilterChip('DESPESA', _filtroTipo, (v) => setState(() => _filtroTipo = v)),
             ]),
             Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
               _buildFilterChip('TODOS', _filtroStatus, (v) => setState(() => _filtroStatus = v)),
               _buildFilterChip('PAGO', _filtroStatus, (v) => setState(() => _filtroStatus = v)),
               _buildFilterChip('ABERTO', _filtroStatus, (v) => setState(() => _filtroStatus = v)),
             ]),
        ]))
    ]));
  }
  
  Widget _buildFilterChip(String label, String current, Function(String) onSelect) {
    return FilterChip(label: Text(label), selected: current == label, onSelected: (_) => onSelect(label));
  }

  Widget _buildResumoFiltro(List<TransacaoFinanceira> lista) {
    double r=0, d=0; for(var t in lista) { if(t.tipo=='RECEITA') r+=t.valor; else d+=t.valor; }
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(12), color: Colors.grey[200], child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_itemResumo("R", r, color: Colors.green), _itemResumo("D", d, color: Colors.red), _itemResumo("S", r-d, color: Colors.blue)]));
  }

  Widget _itemResumo(String l, double v, {Color color=Colors.black}) => Column(children:[Text(l), Text(_currencyFormat.format(v), style: TextStyle(color: color, fontWeight: FontWeight.bold))]);


  void _showAbrirCaixaDialog() {
    final c = TextEditingController(text: '0,00');
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Abrir Caixa"), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Saldo Inicial")), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async {
        await Provider.of<FinanceiroService>(context, listen: false).abrirCaixa(double.tryParse(c.text.replaceAll(',', '.')) ?? 0); Navigator.pop(ctx);
    }, child: const Text("ABRIR"))]));
  }
  void _showFecharCaixaDialog(double est) {
     final c = TextEditingController(text: est.toStringAsFixed(2));
     showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Fechar Caixa"), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Saldo Real")), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async {
         await Provider.of<FinanceiroService>(context, listen: false).fecharCaixa(double.tryParse(c.text.replaceAll(',', '.')) ?? 0); Navigator.pop(ctx);
     }, child: const Text("FECHAR"))]));
  }

  void _confirmarExclusao(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Tem certeza que deseja excluir este lançamento?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await Provider.of<FinanceiroService>(context, listen: false).excluirTransacao(id);
                Navigator.pop(ctx);
                _carregarDados();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excluído com sucesso!")));
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("EXCLUIR"),
          )
        ],
      ),
    );
  }

  Future<void> _showMarcarComoPagoDialog(TransacaoFinanceira transacao, bool podeMovimentar) async {
      if (!podeMovimentar) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abra o caixa primeiro!')));
        return;
      }
      if (transacao.dataPagamento != null) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Confirmar Pagamento"), content: Text("Confirmar ${transacao.descricao}?"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Não")), ElevatedButton(onPressed: () async { await Provider.of<FinanceiroService>(context, listen: false).marcarComoPaga(transacao.id); Navigator.pop(ctx); _carregarDados(); }, child: const Text("Sim"))]));
  }

  Future<void> _showAddEditTransacaoDialog({TransacaoFinanceira? transacaoParaEditar}) async {
    final isEditing = transacaoParaEditar != null;
    final _formKey = GlobalKey<FormState>();
    
    final _descController = TextEditingController(text: isEditing ? transacaoParaEditar.descricao : '');
    final _valorController = TextEditingController(text: isEditing ? transacaoParaEditar.valor.toStringAsFixed(2) : '');
    
    String _tipoSelecionado = isEditing ? transacaoParaEditar.tipo : 'DESPESA';
    CategoriaFinanceira? _catSelecionada;
    Paciente? _pacienteSelecionado;
    DateTime _dataVenc = isEditing ? transacaoParaEditar.dataVencimento : DateTime.now();
    bool _repetir = false;
    int _qtdParcelas = 2; 

    List<CategoriaFinanceira> _categorias = [];
    List<Paciente> _pacientes = [];
    
    try {
        final financeiroService = Provider.of<FinanceiroService>(context, listen: false);
        final pacienteService = Provider.of<PacienteService>(context, listen: false);
        _categorias = await financeiroService.getCategorias();
        _pacientes = await pacienteService.getPacientes();

        if (isEditing) {
          try {
             _catSelecionada = _categorias.firstWhere((c) => c.nome == transacaoParaEditar.categoriaNome); 
          } catch (e) {}
        }
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categoriasFiltradas = _categorias.where((c) => c.tipo == _tipoSelecionado).toList();
            
            return AlertDialog(
              title: Text(isEditing ? 'Editar Transação' : 'Lançar Transação'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Expanded(child: RadioListTile<String>(
                            title: const Text("Despesa"), 
                            value: 'DESPESA', 
                            groupValue: _tipoSelecionado, 
                            onChanged: isEditing ? null : (v) => setModalState(() => _tipoSelecionado = v!)
                          )), 
                          Expanded(child: RadioListTile<String>(
                            title: const Text("Receita"), 
                            value: 'RECEITA', 
                            groupValue: _tipoSelecionado, 
                            onChanged: isEditing ? null : (v) => setModalState(() => _tipoSelecionado = v!)
                          ))
                        ]),
                        TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição*'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null,),
                        TextFormField(controller: _valorController, decoration: const InputDecoration(labelText: 'Valor (R\$)*'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '0') ?? 0) <= 0 ? 'Inválido' : null,),
                        
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
                        
                        ListTile(
                          title: Text("Vencimento: ${DateFormat('dd/MM/yyyy').format(_dataVenc)}"),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                             final d = await showDatePicker(context: context, initialDate: _dataVenc, firstDate: DateTime(2020), lastDate: DateTime(2030));
                             if (d != null) setModalState(() => _dataVenc = d);
                          },
                        ),

                        if (!isEditing) ...[
                          const Divider(),
                          SwitchListTile(title: const Text("Repetir?"), value: _repetir, onChanged: (val) => setModalState(() => _repetir = val),),
                          if (_repetir) Row(children: [const Text("Qtd: "), SizedBox(width: 50, child: TextFormField(initialValue: _qtdParcelas.toString(), keyboardType: TextInputType.number, onChanged: (v) => _qtdParcelas = int.tryParse(v) ?? 1))]),
                        ]
                    ]),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        final service = Provider.of<FinanceiroService>(context, listen: false);
                        final valor = double.parse(_valorController.text.replaceAll(',', '.'));
                        
                        if (isEditing) {
                          await service.editarTransacao(
                            id: transacaoParaEditar!.id,
                            descricao: _descController.text,
                            valor: valor,
                            tipo: _tipoSelecionado,
                            categoriaId: _catSelecionada!.id, 
                            formaPagamento: 'DINHEIRO', 
                          );
                        } else {
                          await service.addTransacao(
                            descricao: _descController.text, 
                            valor: valor, 
                            tipo: _tipoSelecionado, 
                            dataVencimento: _dataVenc, 
                            categoriaId: _catSelecionada!.id, 
                            pacienteId: _pacienteSelecionado?.id, 
                            repetir: _repetir, 
                            parcelas: _qtdParcelas
                          );
                        }
                        
                        Navigator.pop(context);
                        _carregarDados(); 
                      } catch (e) { 
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); 
                      }
                    }
                  }, child: Text(isEditing ? 'Salvar Alterações' : 'Salvar')),
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
  
  void _showConfigNotificacao() async {
    final notifService = Provider.of<NotificacaoService>(context, listen: false);
    String atual = await notifService.getFrequencia();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Configurar Lembretes"), content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text("Diariamente"), leading: Radio(value: 'DIARIO', groupValue: atual, onChanged: (v) { notifService.setFrequencia(v.toString()); Navigator.pop(ctx); })),
            ListTile(title: const Text("Desativar"), leading: Radio(value: 'OFF', groupValue: atual, onChanged: (v) { notifService.setFrequencia(v.toString()); Navigator.pop(ctx); })),
    ])));
  }
}