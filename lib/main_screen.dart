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
import 'configuracao_screen.dart'; // Import da nova tela

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  // Listas de abas (serão preenchidas no initState)
  final List<Widget> _telas = [];
  final List<BottomNavigationBarItem> _abas = [];

  @override
  void initState() {
    super.initState();
    _buildTabs();
  }

  // O método que constrói as abas (corrigido)
  void _buildTabs() {
    final authService = Provider.of<AuthService>(context, listen: false);

    _telas.clear();
    _abas.clear();

    // --- LÓGICA DE LICENÇA E PERMISSÃO ---
    
    // 1. Define o plano do utilizador
    // (O plano TESTE dá acesso a tudo, como o GESTAO/ENTERPRISE)
    bool temPlanoPremium = 
        authService.licencaPlano == TipoPlano.GESTAO ||
        authService.licencaPlano == TipoPlano.ENTERPRISE ||
        authService.licencaPlano == TipoPlano.TESTE;

    // 2. GESTOR (Admin/Coordenador)
    if (authService.isGestor) {
      
      // Só mostra o Dashboard se for Premium
      if (temPlanoPremium) {
        _telas.add(const DashboardScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));
      }
      
      // Só mostra o Financeiro se for Premium
      if (temPlanoPremium) {
        _telas.add(const FinanceiroScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.monetization_on),
          label: 'Financeiro',
        ));
      }
      
      // Só mostra o Estoque se for Premium
      if (temPlanoPremium) {
        _telas.add(const EstoqueScreen());
        _abas.add(const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Estoque',
        ));
      }
    }

    // 3. ENFERMAGEM (Enfermeiro/Técnico)
    if (authService.isEnfermagem) {
      _telas.add(const EnfermagemScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.medication_liquid),
        label: 'Enfermagem',
      ));
    }
    
    // 4. Abas Padrão (Todos veem)
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

    // 5. Abas de ADMIN (Admin)
    if (authService.isAdmin) {
      _telas.add(const InternacaoScreen());
      _abas.add(const BottomNavigationBarItem(
        icon: Icon(Icons.king_bed_outlined),
        label: 'Internação',
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
  }

  // O método que muda de aba
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // O MÉTODO 'BUILD' QUE ESTAVA FALTANDO
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _telas.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _abas,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).canvasColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
      ),
    );
  }
} // <-- Fim da classe _MainScreenState