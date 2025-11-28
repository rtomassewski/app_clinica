// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Services e Telas
import 'auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'assinatura_screen.dart';

// Services de Domínio
import 'paciente_service.dart';
import 'gestao_service.dart';
import 'internacao_service.dart';
import 'enfermagem_service.dart';
import 'relatorios_service.dart';
import 'financeiro_service.dart';
import 'estoque_service.dart';
import 'impressoes_service.dart';
import 'configuracao_service.dart';
import 'agenda_service.dart';
import 'procedimento_service.dart';
import 'evolucao_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null); 

  runApp(
    MultiProvider(
      providers: [
        // 1. Inicia o AuthService e já tenta recuperar o token salvo (Auto-Login)
        ChangeNotifierProvider(
          create: (context) => AuthService()..tryAutoLogin(),
        ),
        
        // 2. Todos os outros services dependem do AuthService para pegar o Token
        ProxyProvider<AuthService, AgendaService>(
          update: (_, auth, __) => AgendaService(auth),
        ),
        ProxyProvider<AuthService, PacienteService>(
          update: (_, auth, __) => PacienteService(auth),
        ),
        ProxyProvider<AuthService, GestaoService>(
          update: (_, auth, __) => GestaoService(auth),
        ),
        ProxyProvider<AuthService, InternacaoService>(
          update: (_, auth, __) => InternacaoService(auth),
        ),
        ProxyProvider<AuthService, EnfermagemService>(
          update: (_, auth, __) => EnfermagemService(auth),
        ),
        ProxyProvider<AuthService, RelatoriosService>(
          update: (_, auth, __) => RelatoriosService(auth),
        ),
        ProxyProvider<AuthService, FinanceiroService>(
          update: (_, auth, __) => FinanceiroService(auth),
        ),
        ProxyProvider<AuthService, EstoqueService>(
          update: (_, auth, __) => EstoqueService(auth),
        ),
        ProxyProvider<AuthService, ImpressoesService>(
          update: (_, auth, __) => ImpressoesService(auth),
        ),
        ProxyProvider<AuthService, ConfiguracaoService>(
          update: (_, auth, __) => ConfiguracaoService(auth),
        ),
        ProxyProvider<AuthService, ProcedimentoService>(
          update: (_, auth, __) => ProcedimentoService(auth),
        ),
        ProxyProvider<AuthService, EvolucaoService>(
          update: (_, auth, __) => EvolucaoService(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema da Clínica',
      theme: ThemeData(
        primarySwatch: Colors.teal, // Mudei para teal para combinar com as outras telas
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false, // Mantém estilo clássico se preferir
      ),
      // O Consumer escuta o AuthService.
      // Sempre que 'login' ou 'logout' for chamado, ele reconstrói essa parte.
      home: Consumer<AuthService>(
        builder: (context, auth, child) {
          
          // 1. Se NÃO está logado -> Mostra Login
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

          // 2. Se ESTÁ logado -> Verifica status da licença
          final status = auth.licencaStatus;
          
          if (status == StatusLicenca.ATIVA || status == StatusLicenca.TESTE) {
            return const MainScreen();
          } else {
            return const AssinaturaScreen();
          }
        },
      ),
    );
  }
}