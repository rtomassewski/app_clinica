// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'paciente_service.dart'; 
import 'auth_service.dart';
import 'paciente_detalhe_screen.dart';
import 'paciente_add_screen.dart';
import 'perfil_screen.dart';
import 'notificacao_service.dart';
import 'notificacoes_screen.dart';
import 'loja_screen.dart'; // Certifique-se que este arquivo existe

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Paciente>>? _pacientesFuture;

  @override
  void initState() {
    super.initState();
    _refreshPacientes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarVerificacaoNotificacoes();
    });
  }

  Future<void> _iniciarVerificacaoNotificacoes() async {
    final notifService = Provider.of<NotificacaoService>(context, listen: false);
    await notifService.init(); 
    await notifService.verificarPendencias(); 
  }

  void _refreshPacientes() {
    setState(() {
      _pacientesFuture = Provider.of<PacienteService>(context, listen: false).getPacientes();
    });
  }
  
  Future<void> _navegarParaAddPaciente() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PacienteAddScreen(),
      ),
    );

    if (resultado == true) {
      _refreshPacientes();
    }
  }

  // --- NOVO: Lógica para adicionar crédito via Menu ---
  void _exibirDialogAdicionarCredito() {
    final idController = TextEditingController();
    final valorController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Adicionar Crédito"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Informe o ID do paciente e o valor a ser creditado."),
            const SizedBox(height: 10),
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "ID do Paciente", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Valor (R\$)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              // AQUI: Você chamaria o LojaService.adicionarCredito(...)
              // Por enquanto, apenas fecha e mostra mensagem
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Crédito de R\$ ${valorController.text} solicitado para o Paciente ${idController.text}!"))
              );
            },
            child: const Text("CONFIRMAR"),
          ),
        ],
      ),
    );
  }

  // --- NOVO: Constrói o Menu Lateral ---
  Widget _buildDrawer(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final usuario = auth.usuarioLogado;

    return Drawer(
      child: Column(
        children: [
          // Cabeçalho do Menu com dados do Usuário
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF00ACC1), // Ciano do seu tema
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                usuario?.nomeCompleto.isNotEmpty == true 
                    ? usuario!.nomeCompleto[0].toUpperCase() 
                    : "A",
                style: const TextStyle(fontSize: 24, color: Color(0xFF00ACC1)),
              ),
            ),
            accountName: Text(usuario?.nomeCompleto ?? "Usuário"),
            accountEmail: Text(usuario?.email ?? "email@clinica.com"),
          ),
          
          // Itens do Menu
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            onTap: () => Navigator.pop(context), // Fecha o menu
          ),
          
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Loja / Produtos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const LojaScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Adicionar Créditos'),
            onTap: () {
              Navigator.pop(context);
              _exibirDialogAdicionarCredito();
            },
          ),
          
          const Divider(), // Linha divisória
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              // Navegar para configurações se tiver tela
              Navigator.pop(context);
            },
          ),
          
          const Spacer(), // Empurra o Sair para o final
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair do Sistema', style: TextStyle(color: Colors.red)),
            onTap: () {
              auth.logout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThomasMedSoft'),
        actions: [
          // --- 1. BOTÃO DE NOTIFICAÇÕES ---
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notificações',
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (c) => const NotificacoesScreen())
                  );
                },
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              )
            ],
          ),
          
          // --- 2. BOTÃO DE PERFIL ---
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Meu Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerfilScreen(),
                ),
              );
            },
          ),

          // --- 3. BOTÃO SAIR ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      
      // --- AQUI ESTÁ O MENU LATERAL QUE VOCÊ PEDIU ---
      drawer: _buildDrawer(context),
      // -----------------------------------------------

      body: FutureBuilder<List<Paciente>>(
        future: _pacientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar pacientes.\n${snapshot.error}'));
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final pacientes = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16), // Espaçamento para não grudar nas bordas
              itemCount: pacientes.length,
              itemBuilder: (context, index) {
                final paciente = pacientes[index];
                return Card( // Coloquei num Card para ficar mais bonito no tema novo
                  child: ListTile(
                    title: Text(paciente.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${paciente.status}'),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.person, color: Colors.teal),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PacienteDetalheScreen(
                            pacienteId: paciente.id,
                            pacienteNome: paciente.nomeCompleto,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }

          return const Center(child: Text('Nenhum paciente encontrado.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navegarParaAddPaciente,
        child: const Icon(Icons.add),
        tooltip: 'Novo Paciente',
      ),
    );
  }
}