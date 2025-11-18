// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'paciente_service.dart';
import 'main_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'gestao_service.dart';
import 'assinatura_screen.dart'; 
import 'auth_service.dart';
import 'internacao_service.dart';
import 'enfermagem_service.dart';
import 'relatorios_service.dart';
import 'financeiro_service.dart';
import 'estoque_service.dart';
import 'impressoes_service.dart';
import 'configuracao_service.dart';
import 'agenda_service.dart'; // 1. Garanta que este import está aqui
import 'gestao_service.dart';

void main() async { // 2. TRANSFORME EM 'async'
  // 3. GARANTA QUE O FLUTTER ESTEJA INICIALIZADO
  WidgetsFlutterBinding.ensureInitialized();
  
  // 4. INICIALIZE OS DADOS DE LOCALIZAÇÃO (A CORREÇÃO)
  await initializeDateFormatting('pt_BR', null); 

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthService(),
        ),
        ProxyProvider<AuthService, AgendaService>(
          update: (context, auth, previous) => AgendaService(auth), // <-- ESTA LINHA ESTAVA A FALTAR
        ),
        ProxyProvider<AuthService, PacienteService>(
          update: (context, auth, previous) => PacienteService(auth),
        ),
        ProxyProvider<AuthService, GestaoService>(
          update: (context, auth, previous) => GestaoService(auth),
        ),
        ProxyProvider<AuthService, InternacaoService>(
          update: (context, auth, previous) => InternacaoService(auth),
        ),
        ProxyProvider<AuthService, EnfermagemService>(
          update: (context, auth, previous) => EnfermagemService(auth),
        ),
        ProxyProvider<AuthService, RelatoriosService>(
          update: (context, auth, previous) => RelatoriosService(auth),
        ),
        ProxyProvider<AuthService, FinanceiroService>(
          update: (context, auth, previous) => FinanceiroService(auth),
        ),
        ProxyProvider<AuthService, EstoqueService>(
          update: (context, auth, previous) => EstoqueService(auth),
        ),
        ProxyProvider<AuthService, ImpressoesService>(
          update: (context, auth, previous) => ImpressoesService(auth),
        ),
        ProxyProvider<AuthService, ConfiguracaoService>(
          update: (context, auth, previous) => ConfiguracaoService(auth),
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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 2. O "roteador" principal
      home: Consumer<AuthService>(
        builder: (context, auth, child) {
          
          // 1. Se NÃO está autenticado -> Tela de Login
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

          // 2. Se ESTÁ autenticado, checamos a licença
          final status = auth.licencaStatus;
          
          if (status == StatusLicenca.ATIVA || status == StatusLicenca.TESTE) {
            // 2a. Se a licença está OK -> Vai para o App (MainScreen)
            return const MainScreen();
          } else {
            // 2b. Se a licença está INADIMPLENTE, CANCELADA, etc.
            // -> Vai para a Tela de Bloqueio
            return const AssinaturaScreen();
          }
        },
      ),
      // --- FIM DA SUBSTITUIÇÃO ---
    );
  }
}