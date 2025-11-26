import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'procedimento_service.dart';

class ProcedimentosScreen extends StatefulWidget {
  const ProcedimentosScreen({Key? key}) : super(key: key);

  @override
  State<ProcedimentosScreen> createState() => _ProcedimentosScreenState();
}

class _ProcedimentosScreenState extends State<ProcedimentosScreen> {
  late Future<List<Procedimento>> _futureProcedimentos;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _futureProcedimentos = Provider.of<ProcedimentoService>(context, listen: false).getProcedimentos();
    });
  }

  // Modal para Criar ou Editar
  void _showFormDialog({Procedimento? procedimento}) {
    final isEditing = procedimento != null;
    final _nomeController = TextEditingController(text: isEditing ? procedimento.nome : '');
    final _valorController = TextEditingController(text: isEditing ? procedimento.valor.toStringAsFixed(2) : '');
    final _descController = TextEditingController(text: isEditing ? procedimento.descricao : '');
    bool _ativo = isEditing ? procedimento.ativo : true;
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Procedimento' : 'Novo Procedimento'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Serviço'),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _valorController,
                      decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo obrigatório';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Descrição (Opcional)'),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text("Ativo"),
                        value: _ativo,
                        onChanged: (val) => setStateModal(() => _ativo = val),
                      )
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final service = Provider.of<ProcedimentoService>(context, listen: false);
                      if (isEditing) {
                        await service.updateProcedimento(
                          procedimento.id,
                          _nomeController.text,
                          _valorController.text,
                          _descController.text,
                          _ativo,
                        );
                      } else {
                        await service.addProcedimento(
                          _nomeController.text,
                          _valorController.text,
                          _descController.text,
                        );
                      }
                      Navigator.pop(context);
                      _refreshList();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de Serviços')),
      body: FutureBuilder<List<Procedimento>>(
        future: _futureProcedimentos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum serviço cadastrado.'));

          return ListView.separated(
            itemCount: snapshot.data!.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final proc = snapshot.data![index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: proc.ativo ? Colors.green : Colors.grey,
                  child: const Icon(Icons.medical_services, color: Colors.white),
                ),
                title: Text(proc.nome, style: TextStyle(decoration: proc.ativo ? null : TextDecoration.lineThrough)),
                subtitle: Text(proc.descricao ?? 'Sem descrição'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'R\$ ${proc.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showFormDialog(procedimento: proc),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Novo Serviço',
      ),
    );
  }
}