// lib/paciente_add_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'paciente_service.dart';

class PacienteAddScreen extends StatefulWidget {
  const PacienteAddScreen({Key? key}) : super(key: key);

  @override
  State<PacienteAddScreen> createState() => _PacienteAddScreenState();
}

class _PacienteAddScreenState extends State<PacienteAddScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores dos campos
  final _nomeController = TextEditingController();
  final _nomeSocialController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _respNomeController = TextEditingController();
  final _respTelefoneController = TextEditingController();

  // Helper para selecionar Data de Nascimento
  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // Converte para ISO String (YYYY-MM-DDT00:00:00Z)
      _dataNascController.text = picked.toIso8601String();
    }
  }

  // Ação de Salvar
  Future<void> _salvarPaciente() async {
    if (!_formKey.currentState!.validate()) {
      return; // Se o formulário for inválido, não faz nada
    }

    setState(() { _isLoading = true; });

    try {
      await Provider.of<PacienteService>(context, listen: false).addPaciente(
        nomeCompleto: _nomeController.text,
        nomeSocial: _nomeSocialController.text.isEmpty 
                    ? null 
                    : _nomeSocialController.text,
        cpf: _cpfController.text,
        dataNascimento: _dataNascController.text,
        nomeResponsavel: _respNomeController.text,
        telefoneResponsavel: _respTelefoneController.text,
      );

      // Sucesso
      Navigator.of(context).pop(true); // 1. Volta para a HomeScreen
                                      // 2. Retorna 'true' para sinalizar sucesso

    } catch (e) {
      // Erro
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
        title: const Text('Novo Paciente'),
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
                controller: _nomeSocialController,
                decoration: const InputDecoration(labelText: 'Nome Social (Opcional)'),
              ),
              TextFormField(
                controller: _cpfController,
                decoration: const InputDecoration(labelText: 'CPF*', hintText: 'Apenas números'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.length != 11 ? 'CPF deve ter 11 dígitos' : null,
              ),
              TextFormField(
                controller: _dataNascController,
                decoration: const InputDecoration(labelText: 'Data de Nascimento*'),
                readOnly: true, // Impede digitação
                onTap: () => _selecionarData(context), // Abre o calendário
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 24),
              Text('Informações do Responsável', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _respNomeController,
                decoration: const InputDecoration(labelText: 'Nome do Responsável*'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: _respTelefoneController,
                decoration: const InputDecoration(labelText: 'Telefone do Responsável*'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _salvarPaciente,
                      child: const Text('Salvar Paciente'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}