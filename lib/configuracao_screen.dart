// lib/configuracao_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'configuracao_service.dart';
import 'auth_service.dart'; 

class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({Key? key}) : super(key: key);

  @override
  State<ConfiguracaoScreen> createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores
  late TextEditingController _nomeFantasiaController;
  late TextEditingController _logoUrlController;
  late TextEditingController _enderecoController;
  late TextEditingController _telefoneController;
  
  late ClinicaConfig _configAtual; // Guarda os dados atuais

  @override
  void initState() {
    super.initState();
    // 1. Pega os dados atuais que o AuthService já carregou no login
    _configAtual = Provider.of<AuthService>(context, listen: false).clinicaConfig!;
    
    // 2. Pré-preenche os campos
    _nomeFantasiaController = TextEditingController(text: _configAtual.nomeFantasia);
    _logoUrlController = TextEditingController(text: _configAtual.logoUrl);
    _enderecoController = TextEditingController(text: _configAtual.endereco);
    _telefoneController = TextEditingController(text: _configAtual.telefone);
  }

  // Ação de Salvar
  Future<void> _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    // Monta o DTO (Map) apenas com o que mudou
    final Map<String, dynamic> data = {};
    if (_nomeFantasiaController.text != _configAtual.nomeFantasia) {
      data['nome_fantasia'] = _nomeFantasiaController.text;
    }
    if (_logoUrlController.text != _configAtual.logoUrl) {
      data['logo_url'] = _logoUrlController.text;
    }
    if (_enderecoController.text != _configAtual.endereco) {
      data['endereco'] = _enderecoController.text;
    }
    if (_telefoneController.text != _configAtual.telefone) {
      data['telefone'] = _telefoneController.text;
    }

    if (data.isEmpty) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma alteração detectada.'))
      );
      return;
    }

    try {
      await Provider.of<ConfiguracaoService>(context, listen: false).updateClinica(
        _configAtual.id,
        data,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas! (Refaça o login para ver as mudanças)'), backgroundColor: Colors.green)
      );
      Navigator.of(context).pop(); // Volta para a tela anterior

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
        title: const Text('Configurações da Clínica'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nomeFantasiaController,
                decoration: const InputDecoration(labelText: 'Nome Fantasia*'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(labelText: 'URL do Logo (ex: https://...)'),
                // (Validação de URL no back-end já protege)
              ),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: 'Endereço (para Impressões)'),
              ),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone (para Impressões)'),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _salvarConfiguracoes,
                      child: const Text('Salvar Configurações'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}