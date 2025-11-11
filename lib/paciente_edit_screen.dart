// lib/paciente_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'paciente_service.dart'; // Para o service e o modelo
import 'package:intl/intl.dart';


class PacienteEditScreen extends StatefulWidget {
  // 1. Recebe os dados do paciente que será editado
  final PacienteDetalhado paciente;

  const PacienteEditScreen({Key? key, required this.paciente}) : super(key: key);

  @override
  State<PacienteEditScreen> createState() => _PacienteEditScreenState();
}

class _PacienteEditScreenState extends State<PacienteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores dos campos
  
  late TextEditingController _nomeController;
  late TextEditingController _nomeSocialController;
  late TextEditingController _cpfController;
  late TextEditingController _dataNascController;
  late TextEditingController _respNomeController;
  late TextEditingController _respTelefoneController;
  late StatusPaciente _statusSelecionado;

  @override
  void initState() {
    super.initState();
    // 2. Pré-preenche os campos com os dados existentes
    final p = widget.paciente;
    _nomeController = TextEditingController(text: p.nomeCompleto);
    _nomeSocialController = TextEditingController(text: p.nomeSocial);
    _cpfController = TextEditingController(text: p.cpf);
    _dataNascController = TextEditingController(text: p.dataNascimento.toIso8601String());
    _respNomeController = TextEditingController(text: p.nomeResponsavel);
    _respTelefoneController = TextEditingController(text: p.telefoneResponsavel);
    _statusSelecionado = StatusPaciente.values.firstWhere(
  (e) => e.name == p.status,
  orElse: () => StatusPaciente.ATIVO,
);
  }

  // Helper para selecionar Data de Nascimento
  Future<void> _selecionarData(BuildContext context) async {
    final DateTime initial = DateTime.tryParse(_dataNascController.text) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dataNascController.text = picked.toIso8601String();
    }
  }

  // Ação de Salvar
  Future<void> _salvarPaciente() async {
    if (!_formKey.currentState!.validate()) {
      return; 
    }
    setState(() { _isLoading = true; });

    // 3. (Importante) Monta o DTO (Map) APENAS com o que mudou
    //    Isso evita enviar campos que o usuário não queria alterar.
    final Map<String, dynamic> data = {};
    if (_nomeController.text != widget.paciente.nomeCompleto) {
      data['nome_completo'] = _nomeController.text;
    }
    if (_nomeSocialController.text != widget.paciente.nomeSocial) {
      data['nome_social'] = _nomeSocialController.text;
    }
    if (_cpfController.text != widget.paciente.cpf) {
      data['cpf'] = _cpfController.text;
    }
    if (_dataNascController.text != widget.paciente.dataNascimento.toIso8601String()) {
      data['data_nascimento'] = _dataNascController.text;
    }
    if (_respNomeController.text != widget.paciente.nomeResponsavel) {
      data['nome_responsavel'] = _respNomeController.text;
    }
    if (_respTelefoneController.text != widget.paciente.telefoneResponsavel) {
      data['telefone_responsavel'] = _respTelefoneController.text;
    }
    if (_statusSelecionado.name != widget.paciente.status) {
  data['status'] = _statusSelecionado.name;
}

    // Se nada mudou, apenas volte
    if (data.isEmpty) {
      Navigator.of(context).pop(false); // Retorna 'false' (sem refresh)
      return;
    }

    try {
      await Provider.of<PacienteService>(context, listen: false).updatePaciente(
        widget.paciente.id,
        data,
      );
      
      Navigator.of(context).pop(true); // 1. Volta
                                      // 2. Retorna 'true' (para atualizar a tela anterior)
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
        title: const Text('Editar Paciente'),
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
                decoration: InputDecoration(
                  labelText: 'Data de Nascimento*',
                  // Mostra a data formatada
                  hintText: DateFormat('dd/MM/yyyy').format(DateTime.parse(_dataNascController.text)),
                ),
                readOnly: true,
                onTap: () => _selecionarData(context),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StatusPaciente>(
                value: _statusSelecionado,
                decoration: const InputDecoration(labelText: 'Status do Paciente*'),
                items: const [
                  DropdownMenuItem(value: StatusPaciente.ATIVO, child: Text('ATIVO (Internado)')),
                  DropdownMenuItem(value: StatusPaciente.ALTA, child: Text('ALTA (Finalizado)')),
                  DropdownMenuItem(value: StatusPaciente.EVADIDO, child: Text('EVADIDO (Abandono)')),
                ],
                onChanged: (v) => setState(() => _statusSelecionado = v!),
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
                      child: const Text('Salvar Alterações'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}