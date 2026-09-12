# Geny Assistant — Documentação Técnica de Desenvolvimento

> **Versão do documento:** 1.0
> **Nome do produto:** Geny Assistant
> **Pacote Android:** `com.carsaimz.genyassistant`
> **Classificação:** Assistente virtual on-device com controle de sistema (root e não-root)
> **Público-alvo:** Desenvolvedores, arquitetos, mantenedores e auditores do projeto

---

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Princípios de Design](#2-princípios-de-design)
3. [Arquitetura de Alto Nível](#3-arquitetura-de-alto-nível)
4. [Stack Tecnológica](#4-stack-tecnológica)
5. [Estrutura do Repositório](#5-estrutura-do-repositório)
6. [Módulos Funcionais](#6-módulos-funcionais)
7. [Camada de Modelos de IA](#7-camada-de-modelos-de-ia)
8. [Suporte Multilíngue](#8-suporte-multilíngue)
9. [Funcionalidades — Sem Root](#9-funcionalidades--sem-root)
10. [Funcionalidades — Com Root](#10-funcionalidades--com-root)
11. [Integração com Dispositivos Externos](#11-integração-com-dispositivos-externos)
12. [Sistema de Ferramentas (Tool Calling)](#12-sistema-de-ferramentas-tool-calling)
13. [Segurança e Privacidade](#13-segurança-e-privacidade)
14. [Permissões Android](#14-permissões-android)
15. [Persistência e Memória](#15-persistência-e-memória)
16. [Interface e Experiência do Usuário](#16-interface-e-experiência-do-usuário)
17. [Pipeline de Build e CI/CD](#17-pipeline-de-build-e-cicd)
18. [Testes e Qualidade](#18-testes-e-qualidade)
19. [Distribuição e Versionamento](#19-distribuição-e-versionamento)
20. [Roadmap de Desenvolvimento](#20-roadmap-de-desenvolvimento)
21. [Riscos e Mitigações](#21-riscos-e-mitigações)
22. [Licenciamento e Conformidade](#22-licenciamento-e-conformidade)
23. [Apêndices](#23-apêndices)

---

## 1. Visão Geral

### 1.1 Propósito

O Geny Assistant é um assistente virtual Android de código aberto, projetado para operar de forma local-first, com capacidade de controlar o dispositivo hospedeiro (com e sem root) e dispositivos conectados. O sistema prioriza privacidade, auditabilidade e modularidade.

### 1.2 Objetivos primários

- Executar inferência de IA localmente, sem dependência obrigatória de nuvem.
- Oferecer controle abrangente do dispositivo via APIs oficiais do Android e, opcionalmente, via privilégios de superusuário.
- Suportar múltiplos backends de IA: modelos locais, APIs remotas e servidores LLM próprios.
- Ser multilíngue por design, não por tradução posterior.
- Manter arquitetura extensível para integração com dispositivos externos.

### 1.3 Não-objetivos

- Não é um assistente baseado em nuvem obrigatória.
- Não coleta telemetria, analytics ou dados de uso.
- Não distribui modelos de IA embutidos no APK.
- Não executa comandos arbitrários oriundos do modelo sem validação explícita.

---

## 2. Princípios de Design

1. **Local-first:** toda funcionalidade essencial deve operar sem internet.
2. **Privacidade por padrão:** nenhum dado sai do dispositivo sem ação explícita do usuário.
3. **Menor privilégio:** permissões e root são solicitados apenas quando uma função específica exige.
4. **Separação de camadas:** UI, orquestração, inferência e ferramentas são independentes.
5. **Extensibilidade controlada:** ferramentas são registradas explicitamente; o modelo escolhe entre elas, não inventa comandos.
6. **Confirmação humana para ações sensíveis:** enviar mensagens, discar, apagar arquivos, gastar dinheiro e executar root exigem confirmação.
7. **Auditabilidade:** todo o código é versionado, revisável e reproduzível via CI.
8. **Determinismo de build:** versões fixas de NDK, SDK, Rust, Node e submodules.

---

## 3. Arquitetura de Alto Nível

O sistema é organizado em sete camadas, cada uma com responsabilidade única e comunicação por interfaces bem definidas.

### 3.1 Camada de Apresentação

Responsável por toda a interação visual e por voz. Inclui:

- Interface principal do assistente (chat, histórico, configurações).
- Overlay flutuante (HUD) sobre outros aplicativos.
- Notificações persistentes do serviço em primeiro plano.
- Telas de onboarding, seleção de modelo e gerenciamento de permissões.

### 3.2 Camada de Orquestração

Núcleo lógico do assistente. Decide o fluxo entre entrada do usuário, modelo de IA e execução de ferramentas. Inclui:

- Gerenciador de sessão e contexto.
- Roteador de intenções.
- Validador de chamadas de ferramentas.
- Sistema de confirmação para ações sensíveis.
- Fila de tarefas e priorização.

### 3.3 Camada de Modelos de IA

Abstrai todos os backends possíveis:

- LLM local (inferência on-device).
- API remota (gratuita, free-tier ou paga).
- Servidor LLM próprio do usuário (self-hosted).
- STT (voz para texto).
- TTS (texto para voz).
- Embeddings para memória semântica.
- Wake word.

### 3.4 Camada de Ferramentas

Conjunto de capacidades executáveis. Cada ferramenta é uma unidade isolada com nome, descrição, esquema de parâmetros, requisitos de permissão e nível de confirmação. Divide-se em:

- Ferramentas de sistema (sem root).
- Ferramentas privilegiadas (com root).
- Ferramentas de integração externa.

### 3.5 Camada de Acesso ao Sistema

Interfaces com o Android:

- Intents e Activities.
- Serviços em primeiro plano.
- Acesso a arquivos via SAF.
- NotificationListenerService.
- Acessibilidade (opcional).
- Root (quando disponível).

### 3.6 Camada de Persistência

- Banco relacional para configurações, histórico e fatos.
- Banco vetorial para memória semântica.
- Armazenamento seguro para chaves de API e credenciais.
- Cache de modelos e artefatos.

### 3.7 Camada de Infraestrutura

- Pipeline de build e CI/CD.
- Gerenciador de downloads de modelos.
- Sistema de logs locais.
- Mecanismo de atualização de componentes.

---

## 4. Stack Tecnológica

### 4.1 Linguagens e justificativa

| Camada | Linguagem | Justificativa |
|---|---|---|
| Interface e lógica de app | TypeScript | Produtividade, tipagem, ecossistema, integração com Capacitor |
| Ponte Android nativa | Kotlin | Linguagem oficial Android, coroutines, acesso a SDK |
| Núcleo de orquestração | Rust | Performance de C++ com segurança de memória, ideal para áudio e concorrência |
| Inferência de IA | C/C++ | Bibliotecas maduras (llama.cpp, whisper.cpp, ONNX Runtime, Piper) |
| Ferramentas do usuário | Lua | Leve, sandboxável, embedável, sem recompilação |
| Persistência | SQLite | Padrão, leve, confiável, com extensões vetoriais |

### 4.2 Frameworks e bibliotecas principais

- **Capacitor** — ponte entre web e nativo.
- **Jetpack Compose** — UI nativa complementar (overlay, telas críticas).
- **Hilt** — injeção de dependência no lado Kotlin.
- **Room** — acesso a SQLite no lado Kotlin.
- **llama.cpp** — inferência de LLM local.
- **whisper.cpp** — reconhecimento de fala local.
- **Piper** — síntese de voz local.
- **ONNX Runtime** — execução de modelos auxiliares (embeddings, VAD, wake word).
- **UniFFI** — geração automática de bindings Rust ↔ Kotlin.
- **mlua** — integração Lua ↔ Rust.
- **sqlite-vss ou equivalente** — busca vetorial local.

### 4.3 Ferramentas de build

- **Gradle (Kotlin DSL)** — build Android.
- **Cargo** — build Rust.
- **CMake** — build C/C++.
- **NDK** — cross-compilação para Android.
- **Vite** — build do app web.
- **GitHub Actions** — CI/CD.

---

## 5. Estrutura do Repositório

O projeto adota monorepo, com separação clara por camada.

### 5.1 Diretórios principais

- `app/` — aplicação web (TypeScript, Capacitor).
- `android/` — projeto Android (Kotlin, Gradle).
- `core/` — núcleo em Rust.
- `native/` — submodules de bibliotecas C/C++.
- `tools/` — ferramentas em Lua.
- `models/` — diretório de modelos (não versionado).
- `scripts/` — scripts auxiliares de build e download.
- `.github/` — workflows de CI/CD.
- `docs/` — documentação técnica e de usuário.

### 5.2 Convenções

- Submodules para dependências nativas externas.
- Nenhum binário ou modelo versionado.
- Nenhuma credencial em texto plano.
- Versionamento semântico para releases.
- Branches: `main` (estável), `develop` (integração), `feature/*`, `fix/*`.

---

## 6. Módulos Funcionais

### 6.1 Módulo de Conversação

Gerencia o diálogo com o usuário, mantendo contexto de curto e longo prazo. Suporta modos texto, voz e multimodal.

### 6.2 Módulo de Voz

- **Entrada:** captura de áudio, detecção de atividade de voz, transcrição.
- **Saída:** síntese de voz com múltiplas vozes e idiomas.
- **Wake word:** detecção contínua opcional, com baixo consumo.

### 6.3 Módulo de Memória

- Memória de curto prazo (sessão).
- Memória de longo prazo (fatos, preferências, rotinas).
- Memória semântica (embeddings).
- Política de retenção configurável pelo usuário.

### 6.4 Módulo de Ferramentas

Registro, validação e execução de ferramentas. Cada ferramenta declara:

- Nome único.
- Descrição em linguagem natural.
- Esquema de parâmetros.
- Permissões necessárias.
- Nível de confirmação.
- Contexto de execução (app, serviço, root).

### 6.5 Módulo de Automação

Permite ao usuário criar rotinas condicionais (gatilhos, ações, agendamentos) sem programar.

### 6.6 Módulo de Integração Externa

Conectores para dispositivos e serviços externos, sempre opt-in.

### 6.7 Módulo de Segurança

- Gerenciamento de chaves e credenciais.
- Validação de chamadas de ferramentas.
- Sandbox para ferramentas Lua.
- Auditoria local de ações sensíveis.

### 6.8 Módulo de Configuração

Interface unificada para ajustar modelos, idiomas, permissões, privacidade e automações.

---

## 7. Camada de Modelos de IA

### 7.1 Modos de operação

O Geny Assistant suporta três modos, selecionáveis pelo usuário:

1. **Local (offline):** modelos baixados e executados no dispositivo.
2. **Remoto (API):** chamadas a provedores externos.
3. **Próprio (self-hosted):** conexão a um servidor LLM do próprio usuário.

Os modos podem coexistir. O usuário define qual é o padrão e pode alternar por perfil.

### 7.2 Modelos locais suportados

- LLM em formato GGUF (Qwen, Gemma, Phi, Llama, Mistral e derivados).
- STT via whisper.cpp (modelos tiny, base, small, medium).
- TTS via Piper (vozes por idioma).
- Embeddings via ONNX.
- Wake word via ONNX ou biblioteca dedicada.
- VAD via Silero.

### 7.3 APIs remotas suportadas

Categorias:

- **Gratuitas:** provedores com camada gratuita permanente.
- **Free-tier:** provedores com limite gratuito mensal.
- **Premium:** provedores pagos com maior qualidade e limites.

O sistema abstrai o provedor por meio de uma interface comum. O usuário insere sua própria chave de API, armazenada no Keystore do Android.

### 7.4 Servidor LLM próprio

Suporte a servidores compatíveis com a API OpenAI, permitindo:

- Ollama, LM Studio, vLLM, text-generation-webui e similares.
- Servidores expostos via rede local ou túnel privado.
- Autenticação por token configurável.

### 7.5 Gerenciamento de modelos

- Download sob demanda, com verificação de integridade.
- Armazenamento em diretório dedicado do app.
- Remoção individual por modelo.
- Migração entre versões sem perda de configuração.
- Suporte a múltiplos modelos por categoria (LLM, STT, TTS).

### 7.6 Seleção dinâmica de modelo

O sistema pode escolher automaticamente o modelo com base em:

- Complexidade da tarefa.
- Disponibilidade de rede.
- Nível de bateria.
- Temperatura do dispositivo.
- Preferências do usuário.

---

## 8. Suporte Multilíngue

### 8.1 Idiomas principais (obrigatórios)

1. Português (Brasil e Portugal)
2. Inglês
3. Espanhol
4. Francês
5. Alemão
6. Italiano
7. Russo
8. Mandarim
9. Japonês
10. Árabe

### 8.2 Idiomas adicionais (suportados)

Hindi, Coreano, Turco, Holandês, Polonês, Sueco, Indonésio, Tailandês, Vietnamita, Hebraico, Grego, Tcheco, Romeno, Ucraniano e outros conforme disponibilidade de modelos.

### 8.3 Estratégia de localização

- **Interface:** traduções versionadas em arquivos de recursos.
- **Voz (STT/TTS):** modelos específicos por idioma, baixados sob demanda.
- **Modelo de linguagem:** seleção de LLM com suporte ao idioma escolhido.
- **Prompts de sistema:** adaptados por idioma e cultura.
- **Detecção automática:** o sistema identifica o idioma de entrada e ajusta a resposta.
- **Fallback:** se o idioma não estiver disponível localmente, o sistema informa e oferece alternativas.

### 8.4 Direção de texto

Suporte a idiomas da direita para a esquerda (árabe, hebraico) na interface e na renderização de texto.

---

## 9. Funcionalidades — Sem Root

### 9.1 Controle de aplicativos

- Abrir aplicativos por nome ou pacote.
- Alternar entre aplicativos recentes.
- Fechar aplicativos (quando permitido pelo sistema).
- Listar aplicativos instalados.
- Obter informações de pacote.

### 9.2 Comunicação

- Iniciar chamadas telefônicas (via Intent de discagem).
- Enviar mensagens SMS (com confirmação).
- Ler SMS recebidos (com permissão explícita).
- Acessar contatos (somente leitura, com permissão).
- Enviar mensagens por aplicativos de terceiros via Intents.

### 9.3 Notificações

- Ler notificações de outros aplicativos via NotificationListenerService.
- Responder a notificações (quando suportado pelo app emissor).
- Descartar notificações.
- Filtrar notificações por aplicativo ou palavra-chave.

### 9.4 Arquivos e mídia

- Acessar arquivos via Storage Access Framework.
- Criar, ler, editar e excluir arquivos em pastas autorizadas.
- Capturar fotos e vídeos.
- Acessar galeria.
- Realizar OCR em imagens e documentos.
- Compartilhar arquivos entre aplicativos.

### 9.5 Localização e contexto

- Obter localização atual.
- Monitorar mudanças de localização.
- Detectar atividades (caminhada, corrida, condução) com permissão.
- Acessar sensores do dispositivo.

### 9.6 Automação

- Agendar tarefas com WorkManager.
- Criar rotinas condicionais.
- Responder a eventos do sistema (conexão, bateria, hora).
- Integrar com Termux:API para automação avançada sem root.

### 9.7 Produtividade

- Criar e gerenciar notas.
- Gerenciar listas de tarefas.
- Definir alarmes e lembretes.
- Realizar cálculos e conversões.
- Pesquisar na web via navegador padrão.

### 9.8 Acessibilidade (opcional)

- Ler conteúdo da tela via AccessibilityService.
- Interagir com elementos de interface de outros apps.
- Executar ações em nome do usuário (com confirmação).

### 9.9 Web e rede

- Servidor HTTP local para integrações.
- Requisições HTTP a serviços externos.
- Webhooks para automação.

### 9.10 Dispositivos conectados (sem root)

- Bluetooth: pareamento, conexão, controle de áudio.
- Wi-Fi: conexão, informações de rede.
- NFC: leitura de tags (quando suportado).
- Casting: envio de mídia para telas externas.
- Integração com Home Assistant e similares.

---

## 10. Funcionalidades — Com Root

Todas as funcionalidades sem root permanecem disponíveis. O root adiciona capacidades de baixo nível, sempre com confirmação explícita e auditabilidade.

### 10.1 Acesso ao sistema de arquivos

- Leitura e escrita em partições protegidas.
- Acesso a diretórios de dados de outros aplicativos.
- Backup e restauração completos.
- Manipulação de arquivos de sistema.

### 10.2 Gerenciamento de processos

- Listar processos em execução.
- Encerrar processos.
- Monitorar uso de recursos por processo.
- Executar binários em segundo plano.
- Gerenciar daemons.

### 10.3 Controle de hardware

- Ajuste de frequência de CPU e GPU.
- Controle de governadores de energia.
- Gerenciamento térmico.
- Controle de carga da bateria.
- Acesso a interfaces de baixo nível.

### 10.4 Rede avançada

- Configuração de firewall.
- Manipulação de tabelas de roteamento.
- Monitoramento de tráfego.
- Configuração de VPN e proxies.
- Sniffing de pacotes (com finalidade declarada).

### 10.5 Sistema e kernel

- Leitura de logs do kernel.
- Ajuste de parâmetros do kernel.
- Carregamento de módulos.
- Execução de scripts de inicialização.
- Modificação de propriedades do sistema.

### 10.6 Segurança e privacidade avançadas

- Revogação de permissões em massa.
- Bloqueio de anúncios e rastreadores em nível de sistema.
- Isolamento de aplicativos.
- Auditoria de atividades do sistema.

### 10.7 Automação profunda

- Execução de scripts shell arbitrários (com confirmação).
- Agendamento de tarefas via cron.
- Integração com Magisk, KernelSU e APatch.
- Criação de módulos de sistema.

### 10.8 Recuperação e manutenção

- Backup completo do sistema.
- Restauração de partições.
- Limpeza de caches do sistema.
- Diagnóstico avançado.

---

## 11. Integração com Dispositivos Externos

### 11.1 Protocolos suportados

- **MQTT** — comunicação com dispositivos IoT.
- **HTTP/REST** — APIs genéricas.
- **WebSocket** — comunicação bidirecional em tempo real.
- **Bluetooth LE** — dispositivos de baixo consumo.
- **Zigbee e Z-Wave** — via hubs externos.
- **Matter** — padrão emergente de casa conectada.

### 11.2 Plataformas de casa inteligente

- Home Assistant
- OpenHAB
- Domoticz
- SmartThings
- Google Home (via Intents)
- Amazon Alexa (via Skills)

### 11.3 Dispositivos vestíveis

- Smartwatches Android.
- Fones de ouvido Bluetooth.
- Anéis e pulseiras de saúde.
- Sensores diversos.

### 11.4 Veículos

- Android Auto.
- Integração via Bluetooth.
- APIs de fabricantes (quando disponíveis).

### 11.5 Segurança da integração

- Autenticação por token.
- Criptografia de transporte.
- Escopo mínimo de permissões.
- Auditoria de acessos.

---

## 12. Sistema de Ferramentas (Tool Calling)

### 12.1 Conceito

O modelo de IA não executa ações diretamente. Ele seleciona uma ferramenta registrada e fornece parâmetros. A execução é feita pelo núcleo, com validação.

### 12.2 Estrutura de uma ferramenta

Cada ferramenta declara:

- Identificador único.
- Nome legível.
- Descrição em linguagem natural (usada pelo modelo).
- Esquema de parâmetros (tipos, obrigatoriedade, valores permitidos).
- Permissões necessárias.
- Nível de confirmação (nenhuma, simples, explícita, autenticada).
- Contexto de execução.
- Tempo limite.
- Política de erro.

### 12.3 Níveis de confirmação

1. **Nenhuma:** ações inofensivas (consultar hora, listar apps).
2. **Simples:** ações reversíveis (criar nota, definir alarme).
3. **Explícita:** ações com impacto (enviar SMS, discar, apagar arquivo).
4. **Autenticada:** ações críticas (executar root, modificar sistema, transações).

### 12.4 Registro e descoberta

- Ferramentas internas registradas em tempo de build.
- Ferramentas do usuário (Lua) registradas em tempo de execução.
- Ferramentas externas via plugins.
- Catálogo consultável pelo usuário.

### 12.5 Segurança

- Validação estrita de parâmetros.
- Sanitização de entradas.
- Isolamento de execução.
- Auditoria de chamadas.
- Limitação de taxa.
- Bloqueio de ferramentas não autorizadas.

---

## 13. Segurança e Privacidade

### 13.1 Princípios

- Nenhum dado sai do dispositivo sem ação explícita.
- Nenhuma telemetria, analytics ou rastreamento.
- Nenhum anúncio.
- Nenhuma coleta de dados de uso.
- Nenhuma conexão automática com serviços externos.

### 13.2 Armazenamento seguro

- Chaves de API no Android Keystore.
- Credenciais criptografadas em repouso.
- Banco de dados criptografado opcional.
- Exclusão segura de dados sensíveis.

### 13.3 Comunicação

- TLS obrigatório para APIs remotas.
- Verificação de certificados.
- Certificate pinning opcional.
- Nenhuma comunicação em texto plano.

### 13.4 Root

- Root nunca é solicitado automaticamente.
- Root é uma opção explícita nas configurações.
- Cada ação privilegiada exige confirmação.
- Log de auditoria de ações root.

### 13.5 Modelos e dados

- Modelos baixados de fontes verificadas.
- Verificação de integridade por hash.
- Nenhum modelo é executado sem validação.
- Dados de conversa nunca são enviados a terceiros sem consentimento.

### 13.6 Auditoria

- Logs locais rotativos.
- Exportação de logs para análise.
- Revisão de código aberta.
- Build reproduzível.

### 13.7 Resposta a incidentes

- Canal para reporte de vulnerabilidades.
- Política de divulgação responsável.
- Atualizações de segurança prioritárias.

---

## 14. Permissões Android

### 14.1 Estratégia

Permissões são solicitadas em contexto, quando uma funcionalidade é usada pela primeira vez. O usuário pode revogar a qualquer momento.

### 14.2 Permissões previstas

**Armazenamento e arquivos:**

- Leitura e escrita via SAF.
- Acesso a mídia (áudio, vídeo, imagens).

**Voz e áudio:**

- Gravação de áudio.
- Acesso a dispositivos de áudio.

**Comunicação:**

- Chamadas telefônicas.
- SMS (envio e leitura).
- Contatos.

**Notificações:**

- Publicação de notificações.
- Leitura de notificações (permissão especial).

**Sistema:**

- Serviço em primeiro plano.
- Sobreposição de tela.
- Acessibilidade (opcional).
- Ignorar otimizações de bateria.

**Localização:**

- Localização precisa e aproximada.
- Localização em segundo plano (quando necessário).

**Câmera e sensores:**

- Câmera.
- Sensores diversos.

**Rede:**

- Acesso à internet.
- Estado da rede.
- Wi-Fi e Bluetooth.

### 14.3 Transparência

Toda permissão é explicada ao usuário com:

- Motivo.
- Funcionalidade associada.
- Consequência de negar.
- Possibilidade de revogar.

---

## 15. Persistência e Memória

### 15.1 Banco relacional

Armazena:

- Configurações.
- Histórico de conversas.
- Ferramentas registradas.
- Automações.
- Logs de auditoria.

### 15.2 Banco vetorial

Armazena:

- Embeddings de conversas.
- Fatos aprendidos.
- Documentos indexados.
- Preferências semânticas.

### 15.3 Memória de curto prazo

- Sessão atual.
- Contexto recente.
- Buffer de diálogo.

### 15.4 Memória de longo prazo

- Fatos persistentes.
- Preferências do usuário.
- Rotinas recorrentes.
- Entidades conhecidas.

### 15.5 Política de retenção

- Configurável pelo usuário.
- Exclusão manual e automática.
- Exportação e importação.
- Criptografia opcional.

---

## 16. Interface e Experiência do Usuário

### 16.1 Telas principais

- Início (chat).
- Histórico.
- Ferramentas.
- Automações.
- Modelos.
- Idiomas.
- Privacidade.
- Configurações avançadas.
- Sobre e licenças.

### 16.2 Overlay HUD

- Ícone flutuante configurável.
- Acesso rápido a comandos.
- Exibição de status.
- Modo compacto e expandido.
- Personalização visual.

### 16.3 Modos de interação

- Texto.
- Voz.
- Multimodal (texto + voz + imagem).
- Comandos rápidos.
- Wake word.

### 16.4 Acessibilidade

- Suporte a leitores de tela.
- Alto contraste.
- Tamanhos de fonte ajustáveis.
- Navegação por teclado.
- Legendas.

### 16.5 Personalização

- Temas claro, escuro e automático.
- Ícones alternativos.
- Vozes personalizadas.
- Atalhos configuráveis.

---

## 17. Pipeline de Build e CI/CD

### 17.1 Princípios

- Build reproduzível.
- Versões fixas de todas as ferramentas.
- Cache agressivo para reduzir tempo.
- Separação entre lint, teste, build nativo e build de APK.
- Release somente em tags.

### 17.2 Workflows previstos

1. **Lint** — executa em todo push e pull request.
2. **Test** — executa testes unitários de todas as camadas.
3. **Build Native** — compila Rust e C/C++ para múltiplas arquiteturas.
4. **Build APK** — monta o APK de debug e release.
5. **Release** — publica artefatos em tags.

### 17.3 Arquiteturas alvo

- `arm64-v8a` (primária).
- `armeabi-v7a` (secundária).
- `x86_64` (emuladores).

### 17.4 Artefatos

- APK universal.
- APKs por arquitetura (App Bundle).
- Binários nativos.
- Relatórios de teste e cobertura.

### 17.5 Segredos

- Keystore de assinatura.
- Senhas do keystore.
- Tokens de API para testes (quando aplicável).
- Nunca versionados.

### 17.6 Cache

- Rust: cache de compilação por target.
- C/C++: ccache.
- Gradle: cache de dependências e build.
- npm: cache de dependências.
- NDK: cache de instalação.

---

## 18. Testes e Qualidade

### 18.1 Tipos de teste

- **Unitários:** funções isoladas em todas as linguagens.
- **Integração:** interação entre camadas.
- **Instrumentados:** execução em dispositivo ou emulador.
- **End-to-end:** fluxos completos do usuário.
- **Performance:** tempo de inferência, consumo de memória, uso de bateria.
- **Segurança:** análise estática, verificação de dependências.
- **Acessibilidade:** conformidade com diretrizes.

### 18.2 Cobertura

- Mínimo definido por camada.
- Relatórios publicados no CI.
- Bloqueio de merge se cobertura cair.

### 18.3 Análise estática

- Lint para TypeScript, Kotlin, Rust, C/C++ e Lua.
- Detecção de segredos commitados.
- Verificação de dependências vulneráveis.
- Análise de licenças.

### 18.4 Testes em dispositivos

- Matriz de dispositivos variados.
- Versões mínimas e máximas do Android.
- Diferentes arquiteturas.
- Dispositivos com e sem root.

---

## 19. Distribuição e Versionamento

### 19.1 Canais de distribuição

- **GitHub Releases** (primário).
- **F-Droid** (se compatível com políticas).
- **Google Play** (somente se compatível com políticas de acessibilidade e root).

### 19.2 Versionamento

- Versionamento semântico (`MAJOR.MINOR.PATCH`).
- Changelog mantido por release.
- Notas de versão detalhadas.
- Compatibilidade retroativa de configurações.

### 19.3 Assinatura

- Keystore próprio do projeto.
- Guarda segura das chaves.
- Nunca compartilhado com terceiros.

### 19.4 Atualizações

- Verificação manual ou automática (opt-in).
- Download de APK assinado.
- Verificação de integridade.
- Instalação via sistema.

---

## 20. Roadmap de Desenvolvimento

### 20.1 Fase 1 — Fundação

- Estrutura do monorepo.
- Pipeline de CI/CD.
- App Capacitor com interface básica.
- Serviço em primeiro plano.
- Overlay HUD.

### 20.2 Fase 2 — Voz

- Integração de STT local.
- Integração de TTS local.
- Detecção de atividade de voz.
- Wake word opcional.

### 20.3 Fase 3 — LLM local

- Integração de llama.cpp.
- Gerenciamento de modelos.
- Prompt de sistema.
- Contexto de conversa.

### 20.4 Fase 4 — Ferramentas

- Sistema de tool calling.
- Ferramentas essenciais (apps, arquivos, notificações).
- Confirmação para ações sensíveis.

### 20.5 Fase 5 — Memória

- Banco vetorial.
- Embeddings locais.
- Memória de longo prazo.

### 20.6 Fase 6 — APIs remotas

- Suporte a provedores externos.
- Gerenciamento de chaves.
- Seleção dinâmica de backend.

### 20.7 Fase 7 — Root

- Módulo de root opcional.
- Ferramentas privilegiadas.
- Auditoria de ações.

### 20.8 Fase 8 — Dispositivos externos

- MQTT.
- Home Assistant.
- Bluetooth e wearables.

### 20.9 Fase 9 — Multilíngue

- Traduções completas.
- Vozes por idioma.
- Ajuste de prompts por cultura.

### 20.10 Fase 10 — Refinamento

- Performance.
- Acessibilidade.
- Documentação.
- Estabilidade.

---

## 21. Riscos e Mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Performance insuficiente em dispositivos antigos | Alto | Seleção automática de modelo, modo remoto opcional |
| Consumo excessivo de bateria | Alto | Inferência sob demanda, wake word eficiente, modo econômico |
| Fragmentação de hardware | Médio | Testes em matriz ampla, fallbacks |
| Complexidade de build | Alto | CI robusto, cache, documentação |
| Vulnerabilidades em dependências | Alto | Análise contínua, atualizações, isolamento |
| Root mal utilizado | Crítico | Confirmação obrigatória, auditoria, opção desligada por padrão |
| Vazamento de dados | Crítico | Local-first, sem telemetria, criptografia |
| Modelos grandes demais | Médio | Quantização, download sob demanda, alternativas menores |
| Incompatibilidade com políticas de lojas | Médio | Distribuição via GitHub, F-Droid quando possível |
| Abuso por terceiros | Alto | Código aberto, auditoria, canal de reporte |

---

## 22. Licenciamento e Conformidade

### 22.1 Licença do projeto

- Licença de código aberto permissiva — **Apache 2.0** (decidida: compatível com llama.cpp, whisper.cpp, Piper e ONNX Runtime, todos MIT; inclui concessão explícita de patentes).
- Compatibilidade com licenças de dependências.
- Atribuição de terceiros documentada.

### 22.2 Conformidade

- LGPD (Brasil).
- GDPR (União Europeia).
- CCPA (Califórnia).
- Políticas de privacidade das lojas.
- Termos de uso de APIs externas.

### 22.3 Privacidade

- Nenhum dado coletado.
- Nenhum dado compartilhado.
- Nenhuma telemetria.
- Política de privacidade pública e clara.

---

## 23. Apêndices

### 23.1 Glossário

- **LLM:** Large Language Model.
- **STT:** Speech-to-Text.
- **TTS:** Text-to-Speech.
- **VAD:** Voice Activity Detection.
- **GGUF:** formato de modelo para llama.cpp.
- **SAF:** Storage Access Framework.
- **JNI:** Java Native Interface.
- **FFI:** Foreign Function Interface.
- **HUD:** Heads-Up Display (overlay).
- **Tool calling:** mecanismo pelo qual o modelo seleciona ferramentas.

### 23.2 Referências técnicas

- Documentação oficial do Android.
- Documentação do Capacitor.
- Repositórios oficiais de llama.cpp, whisper.cpp, Piper e ONNX Runtime.
- Especificações de segurança do Android.
- Guias de acessibilidade do Android.

### 23.3 Convenções de documentação

- Documentação técnica em `docs/`.
- Documentação de usuário em `docs/user/`.
- Changelog em `CHANGELOG.md`.
- Guia de contribuição em `CONTRIBUTING.md`.
- Código de conduta em `CODE_OF_CONDUCT.md`.

### 23.4 Histórico de revisões

| Versão | Data | Autor | Descrição |
|---|---|---|---|
| 1.0 | 2025-11 | carsaimz | Versão inicial da documentação técnica |
