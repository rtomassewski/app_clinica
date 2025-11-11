// lib/gestao_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gestao_service.dart'; // Para o service e o modelo 'Papel'
import 'auth_service.dart' hide Papel;

class GestaoEditScreen extends StatefulWidget {
  // 1. Recebe o usuário que será editado
  final UsuarioLista usuario;
  // 2. Recebe a lista de papéis (do 'gestao_screen.dart')
  final List<Papel> papeisDisponiveis;

  const GestaoEditScreen({
    Key? key,
    required this.usuario,
    required this.papeisDisponiveis,
  }) : super(key: key);

  @override
  State<GestaoEditScreen> createState() => _GestaoEditScreenState();
}

class _GestaoEditScreenState extends State<GestaoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores
  late TextEditingController _nomeController;
  late Papel _papelSelecionado;
  late bool _estaAtivo;

  @override
  void initState() {
    super.initState();
    // 3. Pré-preenche os campos
    final u = widget.usuario;
    _nomeController = TextEditingController(text: u.nomeCompleto);
    _estaAtivo = u.ativo;
    
    // Encontra o 'Papel' na lista pelo nome
    _papelSelecionado = widget.papeisDisponiveis.firstWhere(
      (p) => p.nome == u.papel,
      orElse: () => widget.papeisDisponiveis.first, // Fallback
    );
  }

  // Ação de Salvar
  Future<void> _salvarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      await Provider.of<GestaoService>(context, listen: false).updateUsuario(
        usuarioId: widget.usuario.id,
        nome: _nomeController.text,
        papelId: _papelSelecionado.id,
        ativo: _estaAtivo,
      );
      Navigator.of(context).pop(true); // Retorna 'true' (sucesso)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Ação de Desativar
  Future<void> _desativarUsuario() async {
    setState(() { _isLoading = true; });
    
    // Confirmação
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desativação'),
        content: Text('Tem certeza que deseja desativar ${widget.usuario.nomeCompleto}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sim, Desativar'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );

    if (confirmar != true) {
      setState(() { _isLoading = false; });
      return;
    }

    // Se confirmou, chama a API
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Checagem extra de segurança no front-end
      if (authService.userName == widget.usuario.nomeCompleto) {
         throw Exception('Não é permitido desativar a si mesmo.');
      }

      await Provider.of<GestaoService>(context, listen: false)
          .desativarUsuario(widget.usuario.id);
      
      Navigator.of(context).pop(true); // Retorna 'true' (sucesso)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuário'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Completo*'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              DropdownButtonFormField<Papel>(
                value: _papelSelecionado,
                decoration: const InputDecoration(labelText: 'Papel*'),
                items: widget.papeisDisponiveis.map((papel) {
                  return DropdownMenuItem(value: papel, child: Text(papel.nome));
                }).toList(),
                onChanged: (v) => setState(() => _papelSelecionado = v!),
              ),
              SwitchListTile(
                title: const Text('Usuário Ativo'),
                value: _estaAtivo,
                onChanged: (v) => setState(() => _estaAtivo = v),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _salvarUsuario,
                      child: const Text('Salvar Alterações'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _desativarUsuario,
                      child: const Text('Desativar Usuário'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}