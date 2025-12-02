import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'financeiro_service.dart';
import 'auth_service.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final financeiroService = Provider.of<FinanceiroService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Central de Notificações"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<TransacaoFinanceira>>(
        future: financeiroService.getTransacoes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // Filtra apenas o que é URGENTE (Vencido ou Vence Hoje/Amanhã)
          final hoje = DateTime.now();
          final alertas = snapshot.data!.where((t) {
            if (t.dataPagamento != null) return false; // Já pago não é alerta
            
            final diasParaVencer = t.dataVencimento.difference(hoje).inDays;
            // Mostra: Vencidos (negativo) ou que vencem nos próximos 3 dias
            return diasParaVencer <= 3; 
          }).toList();

          // Ordena: Mais urgentes primeiro
          alertas.sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));

          if (alertas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertas.length,
            itemBuilder: (ctx, i) {
              final item = alertas[i];
              return _buildNotificacaoCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Tudo tranquilo!",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Nenhuma pendência urgente encontrada.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificacaoCard(TransacaoFinanceira item) {
    final hoje = DateTime.now();
    final dias = item.dataVencimento.difference(hoje).inDays;
    
    Color corStatus;
    IconData icone;
    String textoStatus;

    if (dias < 0) {
      corStatus = Colors.red;
      icone = Icons.warning_amber_rounded;
      textoStatus = "VENCIDA HÁ ${dias.abs()} DIAS";
    } else if (dias == 0) {
      corStatus = Colors.orange;
      icone = Icons.access_time_filled;
      textoStatus = "VENCE HOJE";
    } else {
      corStatus = Colors.blue;
      icone = Icons.calendar_today;
      textoStatus = "VENCE EM $dias DIAS";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: corStatus.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: corStatus.withOpacity(0.1),
          child: Icon(icone, color: corStatus),
        ),
        title: Text(
          item.descricao,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(textoStatus, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 11)),
            Text("Valor: ${_currencyFormat.format(item.valor)}"),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          // Aqui você pode levar para a tela de detalhes ou abrir o modal de pagamento
          // Exemplo: _showPagarDialog(item);
        },
      ),
    );
  }
}