// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'paciente_service.dart'; 
import 'auth_service.dart';
import 'paciente_detalhe_screen.dart';
import 'paciente_add_screen.dart';
import 'perfil_screen.dart';

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
  }
void _refreshPacientes() {
    setState(() {
      _pacientesFuture = Provider.of<PacienteService>(context, listen: false)
          .getPacientes();
    });
  }
  // 5. (NOVO) Função para navegar e atualizar
  Future<void> _navegarParaAddPaciente() async {
    // Navega para a tela de Adicionar
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PacienteAddScreen(),
      ),
    );

    // Se a tela de Adicionar retornou 'true' (sucesso),
    // atualize a lista de pacientes
    if (resultado == true) {
      _refreshPacientes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThomasMedSoft - Pacientes'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Paciente>>(
        future: _pacientesFuture,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar pacientes.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final pacientes = snapshot.data!;
            // Constrói a lista
            return ListView.builder(
              itemCount: pacientes.length,
              itemBuilder: (context, index) {
                final paciente = pacientes[index];
                return ListTile(
                  title: Text(paciente.nomeCompleto),
                  subtitle: Text('Status: ${paciente.status}'),
                  leading: const Icon(Icons.person),
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
                );
              }, // <-- Fim do itemBuilder
            ); // <-- Fim do ListView.builder
          } // <-- Fim do if (snapshot.hasData)

          // 8. Estado de SUCESSO (mas lista vazia)
          return const Center(child: Text('Nenhum paciente encontrado.'));
        }, // <-- Fim do builder
      ), // <-- Fim do FutureBuilder
      floatingActionButton: FloatingActionButton(
        // 6. (ATUALIZADO) Chama a nova função de navegação
        onPressed: _navegarParaAddPaciente,
        child: const Icon(Icons.add),
        tooltip: 'Novo Paciente',
      ),
    );
  }
}