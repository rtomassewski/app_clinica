// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

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
        // 1. Inicia o AuthService e já tenta recuperar o token salvo
        ChangeNotifierProvider(
          create: (context) => AuthService()..tryAutoLogin(),
        ),
        
        // 2. Todos os outros services dependem do AuthService
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

        // --- CORREÇÃO AQUI ---
        // Mudamos de ProxyProvider para ChangeNotifierProxyProvider
        // Isso permite que a tela de Financeiro atualize quando chamarmos notifyListeners()
        ChangeNotifierProxyProvider<AuthService, FinanceiroService>(
          create: (context) => FinanceiroService(Provider.of<AuthService>(context, listen: false)),
          update: (_, auth, previous) => FinanceiroService(auth),
        ),
        // ---------------------

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
  title: 'ThomasSoft Clinica',
  debugShowCheckedModeBanner: false,
  
  // --- A MÁGICA ACONTECE AQUI ---
  theme: ThemeData(
    useMaterial3: true,
    
    // 1. FUNDO MODERNO (Cinza muito claro para dar profundidade)
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    
    // 2. PALETA DE CORES (Baseada no Ciano Neon da Logo)
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF), // Ciano Neon
      primary: const Color(0xFF00ACC1),   // Um tom levemente mais escuro para leitura em fundo branco
      secondary: const Color(0xFF00BCD4),
      surface: Colors.white,              // A cor dos "Cards" será branca pura
    ),

    // 3. TIPOGRAFIA (Google Fonts)
    textTheme: GoogleFonts.interTextTheme().copyWith(
      // Usamos Poppins para títulos e destaques
      headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2D3748)),
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2D3748)),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2D3748)),
    ),

    // 4. ESTILO DOS CARDS (Padrão: Branco, Sombra suave, Borda redonda)
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2, // Sombra suave
      shadowColor: Colors.black12, // Sombra cinza clara (não preta dura)
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Bordas bem arredondadas
      ),
    ),

    // 5. ESTILO DOS CAMPOS DE TEXTO (Inputs modernos)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Espaçamento interno
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Sem borda quando inativo (estilo "clean")
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00ACC1), width: 2), // Ciano ao focar
      ),
      labelStyle: const TextStyle(color: Colors.grey),
    ),

    // 6. BOTÕES (Grandes e Redondos)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00ACC1), // Ciano
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    
    // Ícones e Appbar
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF00ACC1),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
    ),
  ),
      home: Consumer<AuthService>(
        builder: (context, auth, child) {
          
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

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