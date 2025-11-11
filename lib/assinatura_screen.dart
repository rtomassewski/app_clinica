// lib/assinatura_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class AssinaturaScreen extends StatelessWidget {
  const AssinaturaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pega o status da licença do service
    final licencaStatus = Provider.of<AuthService>(context, listen: false).licencaStatus;
    
    String titulo = 'Assinatura Pendente';
    String mensagem = 'Houve um problema com sua assinatura.';
    IconData icone = Icons.warning_amber;

    // Customiza a mensagem baseada no status
    if (licencaStatus == StatusLicenca.INADIMPLENTE) {
      titulo = 'Pagamento Pendente';
      mensagem = 'Não identificamos o pagamento da sua licença. Por favor, regularize sua situação para continuar usando o sistema.';
      icone = Icons.credit_card_off;
    } else if (licencaStatus == StatusLicenca.CANCELADA) {
      titulo = 'Assinatura Cancelada';
      mensagem = 'Sua licença foi cancelada. Entre em contato com o suporte.';
      icone = Icons.block;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloqueado'),
        actions: [
          // Botão de Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                mensagem,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // TODO: Chamar o POST /pagamentos/checkout
                  // (Exatamente como fizemos no back-end)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chamando tela de pagamento... (TODO)')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('Pagar Agora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}