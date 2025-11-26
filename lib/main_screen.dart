// lib/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'agenda_screen.dart';
import 'gestao_screen.dart';
import 'internacao_screen.dart';
import 'enfermagem_screen.dart';
import 'dashboard_screen.dart';
import 'financeiro_screen.dart';
import 'estoque_screen.dart';
import 'configuracao_screen.dart';
import 'procedimentos_screen.dart'; // Import da tela de serviços
import 'login_screen.dart'; // Import para redirecionar ao sair

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  // Listas de abas
  final List<Widget> _telas = [];
  final List<BottomNavigationBarItem> _abas = [];

  @override
  void initState() {
    super.initState();
    // A construção das abas acontece no didChangeDependencies ou build para ter acesso ao provider seguro
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildTabs();
  }

  void _buildTabs() {
    final authService = Provider.of<AuthService>(context, listen: false);

    _telas.clear();
    _abas.clear();

    // 1. DASHBOARD E FINANCEIRO (Apenas Admin com plano Premium)
    if (authService.isAdmin) {
      bool temPlanoPremium = 
          authService.licencaPlano == TipoPlano.GESTAO ||
          authService.licencaPlano == TipoPlano.ENTERPRISE ||
          authService.licencaPlano == TipoPlano.TESTE;

      if (temPlanoPremium) {
        _telas.add(const DashboardScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dash',
        ));
        
        _telas.add(const FinanceiroScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.monetization_on),
          label: 'Finan.',
        ));
        
        _telas.add(const EstoqueScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Estoque',
        ));
      }
    }

    // 2. ENFERMAGEM
    if (authService.isEnfermagem) {
      _telas.add(const EnfermagemScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.medication_liquid),
        label: 'Enf.',
      ));
    }
    
    // 3. ABAS PADRÃO (Pacientes e Agenda)
    _telas.add(const HomeScreen());
    _abas.add(const BottomNavigationBarItem(
      icon: Icon(Icons.people),
      label: 'Pacientes',
    ));

    _telas.add(const AgendaScreen());
    _abas.add(const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today),
      label: 'Agenda',
    ));

    // 4. ABAS EXCLUSIVAS DE ADMIN (Internação, Gestão, Config)
    if (authService.isAdmin) {
      _telas.add(const InternacaoScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.king_bed_outlined),
        label: 'Intern.',
      ));
      
      _telas.add(const GestaoScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'Gestão',
      ));
      
      _telas.add(const ConfiguracaoScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Config.',
      ));
    }
    
    // NOTA: Se o índice selecionado estourar o tamanho da nova lista (ex: ao trocar de usuário), reseta para 0
    if (_selectedIndex >= _telas.length) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- LOGOUT ---
  void _logout() {
    Provider.of<AuthService>(context, listen: false).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recupera dados do usuário para mostrar no Menu Lateral
    final authService = Provider.of<AuthService>(context);
    final usuario = authService.usuarioLogado;

    return Scaffold(
      // 1. AppBar é necessário para mostrar o ícone do Menu (Hamburger)
      appBar: AppBar(
        title: const Text('ThomasMedSoft'),
        centerTitle: true,
      ),
      
      // 2. DRAWER (Menu Lateral) - Aqui ficam os botões extras
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(usuario?.nomeCompleto ?? 'Usuário'),
              accountEmail: Text(usuario?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  usuario?.nomeCompleto.isNotEmpty == true 
                      ? usuario!.nomeCompleto[0].toUpperCase() 
                      : 'U',
                  style: const TextStyle(fontSize: 24.0, color: Colors.teal),
                ),
              ),
              decoration: const BoxDecoration(
                color: Colors.teal,
              ),
            ),
            
            // --- BOTÃO CATÁLOGO DE SERVIÇOS ---
            // (Exibido apenas para Admins ou Gestores)
            if (authService.isAdmin || authService.isGestor)
              ListTile(
                leading: const Icon(Icons.price_check, color: Colors.teal),
                title: const Text('Catálogo de Serviços'),
                onTap: () {
                  Navigator.pop(context); // Fecha o menu
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProcedimentosScreen()),
                  );
                },
              ),
            
            const Divider(),
            
            // Botão de Sair
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Sair'),
              onTap: _logout,
            ),
          ],
        ),
      ),

      // CORPO DA TELA (Muda conforme a aba de baixo selecionada)
      body: _telas.isNotEmpty 
          ? _telas.elementAt(_selectedIndex) 
          : const Center(child: CircularProgressIndicator()),

      // BARRA DE NAVEGAÇÃO INFERIOR
      bottomNavigationBar: _abas.isNotEmpty 
          ? BottomNavigationBar(
              items: _abas,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed, // Importante para mais de 3 itens
              backgroundColor: Theme.of(context).canvasColor,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey[600],
            )
          : null,
    );
  }
}