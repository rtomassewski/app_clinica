import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'financeiro_service.dart';

class NotificacaoService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FinanceiroService financeiroService;

  NotificacaoService(this.financeiroService);

  // Inicializa o plugin
  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuração para iOS (se for usar no futuro)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  // Lógica principal: Verifica contas e notifica
  Future<void> verificarPendencias() async {
    final prefs = await SharedPreferences.getInstance();
    // Pega a preferência: 'DIARIO', 'SEMANAL' ou 'OFF'
    final tipoFrequencia = prefs.getString('notificacao_frequencia') ?? 'DIARIO';

    if (tipoFrequencia == 'OFF') return;

    try {
      // Busca transações do serviço financeiro
      final transacoes = await financeiroService.getTransacoes();
      
      final hoje = DateTime.now();
      final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
      final fimHoje = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
      
      // Define o intervalo de busca
      DateTime dataLimite;
      if (tipoFrequencia == 'SEMANAL') {
        dataLimite = fimHoje.add(const Duration(days: 7));
      } else {
        // DIARIO
        dataLimite = fimHoje;
      }

      // Filtra: Abertas (não pagas) + Vencimento dentro do prazo
      final pendentes = transacoes.where((t) {
        if (t.dataPagamento != null) return false; // Já pagas ignorar
        
        final venc = t.dataVencimento;
        return venc.isAfter(inicioHoje.subtract(const Duration(days: 1))) && 
               venc.isBefore(dataLimite);
      }).toList();

      if (pendentes.isNotEmpty) {
        double total = pendentes.fold(0, (sum, t) => sum + t.valor);
        String titulo = tipoFrequencia == 'DIARIO' ? 'Contas do Dia' : 'Contas da Semana';
        String corpo = 'Você tem ${pendentes.length} contas pendentes totalizando R\$ ${total.toStringAsFixed(2)}. Toque para ver.';
        
        await _mostrarNotificacao(titulo, corpo);
      }
    } catch (e) {
      print("Erro ao verificar notificações: $e");
    }
  }

  Future<void> _mostrarNotificacao(String titulo, String corpo) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_financeiro', 
      'Lembretes Financeiros',
      channelDescription: 'Notificações de contas a pagar e receber',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0, // ID da notificação
      titulo,
      corpo,
      details,
    );
  }

  // Salvar preferência do usuário
  Future<void> setFrequencia(String freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notificacao_frequencia', freq);
  }
  
  Future<String> getFrequencia() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notificacao_frequencia') ?? 'DIARIO';
  }
}