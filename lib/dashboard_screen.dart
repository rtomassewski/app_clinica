// lib/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'relatorios_service.dart';
// (Vamos usar o 'intl' para formatar R$)
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _dashboardFuture;

  // Helper para formatar R$
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture =
          Provider.of<RelatoriosService>(context, listen: false).getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _refreshDashboard,
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          final data = snapshot.data!;
          
          // Constrói a UI com os Cards
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildLeitosCard(data.leitos),
                const SizedBox(height: 12),
                _buildPacientesCard(data.pacientes),
                const SizedBox(height: 12),
                _buildFinanceiroCard(data.financeiro),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets Helper para os Cards ---

  Widget _buildLeitosCard(LeitosData leitos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Ocupação de Leitos', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            // (Mostra um gráfico de "pizza" simples)
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: leitos.taxaOcupacao / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.green[100],
                    color: Colors.green,
                  ),
                  Center(child: Text('${leitos.taxaOcupacao}%', style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpi('Ocupados', leitos.ocupados.toString()),
                _buildKpi('Disponíveis', leitos.disponiveis.toString()),
                _buildKpi('Total', leitos.total.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacientesCard(PacientesData pacientes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Pacientes', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpi('Ativos', pacientes.ativos.toString()),
                _buildKpi('Admissões (Mês)', pacientes.admissoesNoMes.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceiroCard(FinanceiroData financeiro) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Financeiro (Mês)', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _buildKpi('Receitas', _currencyFormat.format(financeiro.receitaMes), color: Colors.green),
            _buildKpi('Despesas', _currencyFormat.format(financeiro.despesaMes), color: Colors.red),
            _buildKpi('Saldo', _currencyFormat.format(financeiro.saldoMes), color: financeiro.saldoMes >= 0 ? Colors.blue : Colors.red),
          ],
        ),
      ),
    );
  }

  // Widget de layout para um KPI (ex: "Ativos: 10")
  Widget _buildKpi(String label, String valor, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
      ],
    );
  }
}