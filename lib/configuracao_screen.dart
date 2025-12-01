// lib/configuracao_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart'; // <--- IMPORTANTE: Importa a classe ClinicaConfig daqui
import 'gestao_service.dart'; // Caso use para salvar, ou use http direto aqui

class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({Key? key}) : super(key: key);

  @override
  State<ConfiguracaoScreen> createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final _nomeFantasiaController = TextEditingController();
  final _razaoSocialController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  void _carregarDadosIniciais() {
    // Busca os dados já carregados no AuthService (que agora é um Objeto, não um Map)
    final authService = Provider.of<AuthService>(context, listen: false);
    final config = authService.clinicaConfig;

    if (config != null) {
      _nomeFantasiaController.text = config.nomeFantasia ?? '';
      _razaoSocialController.text = config.razaoSocial ?? '';
      _cnpjController.text = config.cnpj ?? '';
      _telefoneController.text = config.telefone ?? '';
      _enderecoController.text = config.endereco ?? '';
    }
  }

  @override
  void dispose() {
    _nomeFantasiaController.dispose();
    _razaoSocialController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  Future<void> _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // AQUI: Você deve chamar o serviço que atualiza no backend.
      // Como não tenho o seu 'ConfiguracaoService', vou simular ou usar o GestaoService se tiver.
      // Se não tiver um método pronto, me avise que criamos.
      
      /* Exemplo de chamada:
      await Provider.of<GestaoService>(context, listen: false).updateClinica(
        nomeFantasia: _nomeFantasiaController.text,
        telefone: _telefoneController.text,
        endereco: _enderecoController.text,
        ...
      );
      */
      
      // Simulação de delay para salvar
      await Future.delayed(const Duration(seconds: 1)); 

      // Atualiza o token/perfil localmente para refletir a mudança na hora (Opcional)
      await Provider.of<AuthService>(context, listen: false).tryAutoLogin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se quiser exibir o logo ou dados extras
    // final config = Provider.of<AuthService>(context).clinicaConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações da Clínica'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dados Cadastrais", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              const Divider(),
              const SizedBox(height: 10),

              TextFormField(
                controller: _nomeFantasiaController,
                decoration: const InputDecoration(labelText: 'Nome Fantasia', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _razaoSocialController,
                decoration: const InputDecoration(labelText: 'Razão Social', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cnpjController,
                      decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder()),
                      readOnly: true, // Geralmente CNPJ não se muda fácil
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextFormField(
                      controller: _telefoneController,
                      decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: 'Endereço Completo', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _salvarConfiguracoes,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? "Salvando..." : "SALVAR ALTERAÇÕES"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}