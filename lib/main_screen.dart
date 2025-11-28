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
import 'procedimentos_screen.dart';
// ADICIONEI ESTE IMPORT PARA O DENTISTA USAR:
import 'meus_atendimentos_screen.dart'; 

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
    
    if (_selectedIndex >= _telas.length) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- LOGOUT CORRIGIDO ---
  void _logout() {
    // 1. Fecha o menu lateral primeiro
    Navigator.pop(context); 

    // 2. Chama apenas o logout do serviço.
    // O main.dart vai detectar a mudança e redirecionar para o Login automaticamente.
    // REMOVI O Navigator.pushReplacement QUE CAUSAVA O ERRO.
    Provider.of<AuthService>(context, listen: false).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final usuario = authService.usuarioLogado;

    // Verifica se é profissional de saúde (mas não admin/enfermeiro)
    // para mostrar o botão do Painel de Atendimentos
    bool isEspecialista = !authService.isAdmin && 
                          !authService.isEnfermagem && 
                          !authService.isAtendente &&
                          !authService.isGestor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ThomasMedSoft'),
        centerTitle: true,
      ),
      
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
            if (authService.isAdmin || authService.isGestor)
              ListTile(
                leading: const Icon(Icons.price_check, color: Colors.teal),
                title: const Text('Catálogo de Serviços'),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProcedimentosScreen()),
                  );
                },
              ),

            // --- NOVO: BOTÃO PAINEL DO ESPECIALISTA ---
            // Adicionei isso para que o Dentista consiga acessar a tela que criamos
            if (isEspecialista || authService.isAdmin) 
               ListTile(
                leading: const Icon(Icons.medical_services_outlined, color: Colors.teal),
                title: const Text('Painel do Especialista'),
                subtitle: const Text('Meus Atendimentos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MeusAtendimentosScreen()),
                  );
                },
              ),
            
            const Divider(),
            
            // Botão de Sair
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Sair'),
              onTap: _logout, // Chama a função corrigida
            ),
          ],
        ),
      ),

      body: _telas.isNotEmpty 
          ? _telas.elementAt(_selectedIndex) 
          : const Center(child: CircularProgressIndicator()),

      bottomNavigationBar: _abas.isNotEmpty 
          ? BottomNavigationBar(
              items: _abas,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Theme.of(context).canvasColor,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey[600],
            )
          : null,
    );
  }
}