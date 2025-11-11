// lib/gestao_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gestao_service.dart';
import 'gestao_edit_screen.dart';
class GestaoScreen extends StatefulWidget {
  const GestaoScreen({Key? key}) : super(key: key);

  @override
  State<GestaoScreen> createState() => _GestaoScreenState();
}

class _GestaoScreenState extends State<GestaoScreen> {
  late Future<List<UsuarioLista>> _usuariosFuture;

  // 1. (NOVO) Nossos papéis "hardcoded"
  // Lembre-se: 1=ADMINISTRADOR, 2=MEDICO, 3=PSICOLOGO, etc.
  // (Baseado no 'seed' do back-end)
  final List<Papel> _papeisDisponiveis = [
    Papel(id: 1, nome: 'Administrador'),
    Papel(id: 2, nome: 'Médico'),
    Papel(id: 3, nome: 'Psicólogo'),
    Papel(id: 4, nome: 'Enfermeiro'),
    Papel(id: 5, nome: 'Terapeuta'),
    Papel(id: 6, nome: 'Coordenador'),
    Papel(id: 7, nome: 'Técnico'),
    Papel(id: 8, nome: 'Atendente'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUsuarios();
  }

  void _refreshUsuarios() {
    setState(() {
      _usuariosFuture =
          Provider.of<GestaoService>(context, listen: false).getUsuarios();
    });
  }

  // --- SUBSTITUA ESTA FUNÇÃO ---
  // 2. (NOVO) O modal completo
  Future<void> _showAddUsuarioDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _emailController = TextEditingController();
    final _senhaController = TextEditingController();
    Papel? _papelSelecionado; // Para o dropdown
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Adicionar Novo Usuário'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome Completo'),
                        validator: (value) =>
                            value!.isEmpty ? 'Obrigatório' : null,
                      ),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value!.isEmpty || !value.contains('@')
                                ? 'E-mail inválido'
                                : null,
                      ),
                      TextFormField(
                        controller: _senhaController,
                        decoration: const InputDecoration(labelText: 'Senha Provisória'),
                        obscureText: true,
                        validator: (value) => (value!.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      DropdownButtonFormField<Papel>(
                        value: _papelSelecionado,
                        hint: const Text('Selecione um Papel'),
                        items: _papeisDisponiveis.map((papel) {
                          return DropdownMenuItem(
                            value: papel,
                            child: Text(papel.nome),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => _papelSelecionado = value);
                        },
                        validator: (value) =>
                            value == null ? 'Obrigatório' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => _isSaving = true);
                            
                            try {
                              // Chama a API
                              await Provider.of<GestaoService>(context, listen: false)
                                  .addUsuario(
                                nome: _nomeController.text,
                                email: _emailController.text,
                                senha: _senhaController.text,
                                papelId: _papelSelecionado!.id,
                              );

                              Navigator.of(context).pop(); // Fecha o modal
                              _refreshUsuarios(); // Atualiza a lista

                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setModalState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _navegarParaEditar(UsuarioLista usuario) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestaoEditScreen(
          usuario: usuario,
          papeisDisponiveis: _papeisDisponiveis,
        ),
      ),
    );
    
    // Se a tela de edição retornou 'true', atualize a lista
    if (resultado == true) {
      _refreshUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Equipe'),
      ),
      body: FutureBuilder<List<UsuarioLista>>(
        future: _usuariosFuture,
        builder: (context, snapshot) {
          // ... (o builder do FutureBuilder não muda)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum usuário cadastrado.'));
          }

          final usuarios = snapshot.data!;
          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    usuario.ativo ? Icons.person : Icons.person_off,
                    color: usuario.ativo ? Colors.green : Colors.grey,
                  ),
                  title: Text(usuario.nomeCompleto),
                  subtitle: Text('${usuario.papel} - ${usuario.email}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _navegarParaEditar(usuario),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUsuarioDialog, // Agora chama o modal real
        child: const Icon(Icons.add),
        tooltip: 'Novo Usuário',
      ),
    );
  }
}