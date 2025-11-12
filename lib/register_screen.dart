// lib/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores dos 5 campos
  final _clinicaNomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _adminNomeController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminSenhaController = TextEditingController();

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return; // Validação falhou
    
    setState(() { _isLoading = true; });

    try {
      // Chama o novo método do AuthService
      await Provider.of<AuthService>(context, listen: false).registerTrial(
        nomeFantasia: _clinicaNomeController.text,
        cnpj: _cnpjController.text,
        nomeAdmin: _adminNomeController.text,
        emailAdmin: _adminEmailController.text,
        senhaAdmin: _adminSenhaController.text,
      );
      
      // Se chegar aqui, o login foi um sucesso!
      // O 'notifyListeners()' no AuthService fará o 'main.dart'
      // navegar automaticamente para o MainScreen.
      // (Não precisamos de fazer 'Navigator.pop' aqui)

    } catch (e) {
      // Se a API devolveu um erro (409, 400, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no registo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Apenas para o loading (se o login falhar)
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta de Teste (30 dias)'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dados da Clínica', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clinicaNomeController,
                  decoration: const InputDecoration(labelText: 'Nome Fantasia da Clínica'),
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                TextFormField(
                  controller: _cnpjController,
                  decoration: const InputDecoration(labelText: 'CNPJ (apenas números)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.length != 14 ? 'CNPJ deve ter 14 dígitos' : null,
                ),
                const SizedBox(height: 32),
                Text('Dados do Administrador', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminNomeController,
                  decoration: const InputDecoration(labelText: 'Seu Nome Completo'),
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                TextFormField(
                  controller: _adminEmailController,
                  decoration: const InputDecoration(labelText: 'Seu E-mail (será o login)'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
                ),
                TextFormField(
                  controller: _adminSenhaController,
                  decoration: const InputDecoration(labelText: 'Senha (mín. 6 caracteres)'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitRegister,
                        child: const Text('Iniciar Teste Gratuito'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}