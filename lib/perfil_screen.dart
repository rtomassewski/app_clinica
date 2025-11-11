// lib/perfil_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'paciente_service.dart'; // (Usado para o modelo Profissional)

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({Key? key}) : super(key: key);

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores
  late TextEditingController _nomeController;
  late TextEditingController _registroController;
  late TextEditingController _assinaturaController;
  
  // Dados atuais (para comparação)
  late Profissional _perfilAtual;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);

    // 1. Pega os dados atuais do AuthService
    // (Precisamos buscar o usuário completo, pois o AuthService só tem o 'nome')
    // (Vamos simplificar por agora e usar o que temos)
    
    // --- ATUALIZAÇÃO ---
    // (Precisamos buscar os dados completos do usuário logado)
    // (Vamos adicionar um método rápido ao PacienteService para 'getUsuarioLogado')
    
    // (Vamos simplificar. O AuthService *não* tem o registro e assinatura.)
    // (Vamos usar os dados que *temos* e deixar o resto em branco por enquanto)
    // (Idealmente, o /auth/login deveria retornar 'registro_conselho' e 'assinatura_url')

    _nomeController = TextEditingController(text: authService.userName);
    _registroController = TextEditingController(); // TODO: Carregar do login
    _assinaturaController = TextEditingController(); // TODO: Carregar do login
  }

  // Ação de Salvar
  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      await Provider.of<AuthService>(context, listen: false).updatePerfil(
        nome: _nomeController.text,
        registroConselho: _registroController.text.isEmpty 
            ? null 
            : _registroController.text,
        assinaturaUrl: _assinaturaController.text.isEmpty 
            ? null 
            : _assinaturaController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green)
      );
      Navigator.of(context).pop(); // Volta

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
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
              TextFormField(
                controller: _registroController,
                decoration: const InputDecoration(labelText: 'Registro (Ex: CRM 123456)'),
              ),
              TextFormField(
                controller: _assinaturaController,
                decoration: const InputDecoration(labelText: 'URL da Imagem da Assinatura'),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _salvarPerfil,
                      child: const Text('Salvar Perfil'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}