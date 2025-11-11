Este é o aplicativo front-end (cliente) para o Sistema de Gestão de Clínicas, construído com **Flutter**.

O projeto utiliza uma arquitetura baseada em "Serviços" (separação de lógica) e `Provider` para gestão de estado. Ele consome a [API Back-End (NestJS)](https://github.com/SEU_USUARIO/api-centro-terapeutico) para todas as operações de dados.

O aplicativo é *cross-platform* (multiplataforma) e foi projetado para rodar em **Web (Chrome)** e **Android** a partir de um único código-fonte.

## 🚀 Funcionalidades Principais

* **Autenticação Segura:** Fluxo de Login (JWT) e Logout.
* **Proteção de Licença:** Tela de bloqueio (`AssinaturaScreen`) que verifica o status da licença (`ATIVA`, `INADIMPLENTE`) antes de permitir o acesso.
* **Navegação Baseada em Papel (RBAC):** A barra de navegação principal (abas) é construída dinamicamente com base no papel do usuário logado (Admin, Médico, Enfermeiro, Atendente, etc.).
* **Prontuário Completo:**
    * Lista de Pacientes (com `FAB` para criar novos).
    * Tela de Detalhes do Paciente com 6 abas:
        1.  Informações (com `FAB` para Editar).
        2.  Histórico (Anamnese, com sigilo e `FAB` de Adicionar/Editar).
        3.  Evoluções (com sigilo e `FAB` de Adicionar).
        4.  Prescrições (com `FAB` e modal de seleção de Produtos do Estoque).
        5.  Sinais Vitais (com `FAB` de Adicionar).
        6.  Comportamento (com `FAB` restrito a Coordenadores).
* **Módulo de Agenda:**
    * Visualização em Calendário (`table_calendar`).
    * Lista de agendamentos por dia (via `GET /agendamentos?data_inicio=...`).
    * Modal de criação de agendamento (com checagem de conflito da API).
* **Módulo de Enfermagem:**
    * Tela de "Pendências" (`GET /administracao-medicamentos?status=PENDENTE`).
    * Modal de "Dar Baixa" (Administrar, Recusar, etc.), que atualiza o estoque.
    * Modal de "Aprazamento" (restrito a Enfermeiro/Admin) para agendar medicações.
* **Módulos de Gestão (Restritos a Admin/Gestor):**
    * **Dashboard (BI):** Gráficos e KPIs de finanças e ocupação.
    * **Financeiro (ERP):** Lista de transações (Caixa), `FAB` para lançamentos e botão para gerenciar Categorias.
    * **Estoque:** Lista de produtos, `FAB` para criar novo produto, e botão "Dar Entrada" em cada item.
    * **Internação:** Navegação hierárquica (Alas -> Quartos -> Leitos) com `FAB`s para criar cada nível.
    * **Gestão de Staff:** Lista de usuários e `FAB` para criar novos (com seleção de papel).
* **Impressão:** Botão no prontuário que chama a API (`GET /impressoes/...`) e faz o download ou abre o PDF gerado.

## 🛠 Tech Stack

* **Framework:** Flutter
* **Linguagem:** Dart
* **Gestão de Estado:** Provider
* **HTTP:** `http` (pacote)
* **Componentes:** `table_calendar`, `intl`
* **Armazenamento Seguro:** `flutter_secure_storage`
* **Manipulação de Ficheiros:** `path_provider`, `open_file` (Nativo) / `dart:html` (Web)