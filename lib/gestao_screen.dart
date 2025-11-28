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
  
  // Lista dinâmica que vem do Back-end
  List<Papel> _papeisDisponiveis = [];
  bool _isLoadingPapeis = true;

  @override
  void initState() {
    super.initState();
    _refreshUsuarios();
    _carregarPapeisReais(); 
  }

  // 1. Função que busca a lista de usuários
  void _refreshUsuarios() {
    setState(() {
      _usuariosFuture = Provider.of<GestaoService>(context, listen: false).getUsuarios();
    });
  }

  // 2. Função que busca os cargos (Papéis) reais do banco
  Future<void> _carregarPapeisReais() async {
    try {
      final papeis = await Provider.of<GestaoService>(context, listen: false).getPapeis();
      if (mounted) {
        setState(() {
          _papeisDisponiveis = papeis;
          _isLoadingPapeis = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar papéis: $e");
      if (mounted) {
        setState(() => _isLoadingPapeis = false);
      }
    }
  }

  // --- O Modal de Adicionar Usuário ---
  Future<void> _showAddUsuarioDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _emailController = TextEditingController();
    final _senhaController = TextEditingController();
    final _registroController = TextEditingController(); // CRM, COREN...
    
    Papel? _papelSelecionado;
    bool _isSaving = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Adicionar Novo Usuário'),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
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
                        
                        const SizedBox(height: 10),
                        
                        // --- DROPDOWN DINÂMICO COM LOADING ---
                        if (_isLoadingPapeis)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text("Carregando cargos..."),
                              ],
                            ),
                          )
                        else if (_papeisDisponiveis.isEmpty)
                          const Text("Erro: Nenhum cargo encontrado.", style: TextStyle(color: Colors.red))
                        else
                          DropdownButtonFormField<Papel>(
                            value: _papelSelecionado,
                            hint: const Text('Selecione um Cargo'),
                            isExpanded: true,
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
                        // -------------------------------------
                        
                        const SizedBox(height: 10),
                        
                        TextFormField(
                          controller: _registroController,
                          decoration: const InputDecoration(
                            labelText: 'Registro Profissional (CRM, CRO, CRP...)',
                            helperText: 'Opcional para administrativo',
                          ),
                        ),
                      ],
                    ),
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
                              await Provider.of<GestaoService>(context, listen: false)
                                  .addUsuario(
                                nome: _nomeController.text,
                                email: _emailController.text,
                                senha: _senhaController.text,
                                papelId: _papelSelecionado!.id, // ID REAL do banco
                                registroConselho: _registroController.text.isEmpty
                                    ? null
                                    : _registroController.text,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                _refreshUsuarios();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao salvar: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => _isSaving = false);
                              }
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
                  leading: CircleAvatar(
                    backgroundColor: usuario.ativo ? Colors.teal : Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(usuario.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.papel),
                      Text(usuario.email, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _navegarParaEditar(usuario),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUsuarioDialog,
        child: const Icon(Icons.add),
        tooltip: 'Novo Usuário',
      ),
    );
  }
}