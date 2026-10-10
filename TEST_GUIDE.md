# 🧪 Guia Completo de Testes & Validação de QA — `haze_garages`

Este documento é o **manual definitivo de homologação e testes de QA** do recurso **`haze_garages`**. Ele detalha o passo a passo para testar **cada função, cada comando, cada botão de interface (NUI Modal e Phone App) e cada interação de ox_target**, contemplando todas as novas mecânicas de segurança, permissões e jogabilidade.

---

## 📋 Sumário de Recursos & Atalhos Rápidos

| Recurso | Tipo | Acionamento / Botão | Descrição |
| :--- | :--- | :--- | :--- |
| **Garagem Fixa (NPC)** | 3D / NUI | `ox_target` no Ped ou Tecla `[E]` | Abre o menu NUI Emerald com veículos daquela garagem |
| **Guardar Veículo (3 Formas)** | 3D / Cmd | Tecla `[E]` no carro / Target / `/guardar` | Guarda o carro próprio na garagem física onde você estiver |
| **Marcar Garagens no GPS** | Comando / NUI | `/garagens` ou Botão `📍 MARCAR GARAGEM` | Traça rota imediata até a garagem desejada no minimapa |
| **Menu Meus Veículos** | Comando | Chat `/listarveiculos` | Lista todos os veículos; só retira os da rua (`/estacionar`) |
| **App Telefone** | Celular / NUI | App no `vp_phone` ou `/garagemapp` | Interface mobile com status GPS, rastreamento e valet |
| **Estacionamento Rua** | Comando | Chat `/estacionar` | Estaciona dinamicamente na rua onde o carro estiver |
| **Retirar da Rua** | 3D / Tecla | Tecla `[E]` ao lado da porta do carro | Destranca e devolve o carro estacionado na rua |
| **Deletar & Guardar (DV)** | Comando | Chat `/dv [raio]` ou `/deleteveh` | Guarda carro próprio na garagem fixa mais próxima por cálculo 3D |
| **Apreensão Policial** | Target / Cmd | Target no carro ou `/apreender` | Envia carro com multa e retenção ao pátio do Impound |
| **Pátio Impound** | 3D / NUI | Target no Ped do Impound | Consulta multas, tempo de retenção e liberação bancária |
| **Parquímetro** | Target | `ox_target` no parquímetro | Pagar hora, ver tempo restante ou fiscalizar (polícia) |
| **Multar Irregular** | Target | `ox_target` no veículo (polícia) | Aplica multa de $500 na conta bancária do proprietário |
| **Rastreador GPS** | Item | Usar item `vehicle_tracker` | Instala rastreador permanente com ícone e progressbar de 5s |
| **Jammer de Sinal** | Item | Usar item `tracker_jammer` | Bloqueia temporariamente o GPS do carro por 30 minutos |
| **Transferência** | NUI Button | Botão `📄` no card do veículo | Dispara contrato de transferência se possuir o item |
| **Apelido (Nickname)**| NUI Button | Botão `✏️` no card do veículo | Abre modal para definir apelido customizado do carro |

---

## 🛠️ Checklist de Pré-requisitos do Servidor

Antes de iniciar os testes em jogo, confirme os seguintes itens:
- [x] Recurso `haze_garages` iniciado sem erros no console (`ensure haze_garages`).
- [x] Banco de dados MySQL (`oxmysql`) conectado e tabelas migradas automaticamente.
- [x] Dependências ativas: `qbx_core`, `ox_lib`, `ox_inventory`, `ox_target`.
- [x] Itens registrados com imagens oficiais no `ox_inventory/data/items.lua` e `ox_inventory/web/images/`:
  - `parking_ticket` (Ticket de Parquímetro)
  - `vehicle_tracker` (Rastreador GPS Veicular)
  - `tracker_jammer` (Jammer de Sinal GPS)
  - `vehicle_transfer_contract` (Contrato de Transferência de Veículo)

---

## 🧪 Roteiro de Testes Passo a Passo

---

### 🔹 Teste 1: Inicialização do Recurso & Auto-Migration do Banco
1. No console do servidor F8 ou terminal do servidor:
   ```cmd
   restart haze_garages
   ```
2. **Resultado Esperado**:
   - Mensagem verde no console: `^2[Haze Garages]^7 Tabelas de banco de dados inicializadas e verificadas com sucesso.`
   - Tabelas criadas ou validadas:
     - `haze_street_parking`
     - `haze_fixed_garages`
     - `haze_parking_meters`
     - `haze_vehicle_deformations`
     - `haze_vehicle_trackers`
     - `haze_vehicle_nicknames`
     - `haze_vehicle_impounds`
     - `granolla_vehicle_wear`

---

### 🔹 Teste 2: Garagens Fixas, Peds Customizados & Múltiplas Vagas de Retirada
1. Vá até a **Garagem Central da Praça Legion** (`coords: 215.12, -810.55, 30.7`).
2. Observe o atendente NPC configurado individualmente (`a_m_y_business_01`).
3. Mire com `ox_target` no atendente:
   - Duas opções surgem: **"Garagem Central - Praça Legion"** e **"Guardar Veículo Próximo"**.
4. Selecione abrir a garagem:
   - A NUI **Lation Modern UI (Emerald Edition)** abre na tela com o título da garagem.
   - Os veículos pertencentes ou guardados nesta garagem são listados.
5. **Teste de Múltiplas Vagas Sem Gargalo**:
   - Retire um veículo pelo botão **"🚗 RETIRAR"**.
   - O primeiro veículo surge na vaga 1 (`vec4(222.10, -805.20, 30.6, 140.0)`).
   - Deixe o veículo parado exatamente em cima dessa vaga.
   - Abra a garagem novamente e retire outro carro (ou peça para outro jogador retirar).
   - **Resultado Esperado**: O sistema detecta a vaga ocupada (`IsPositionOccupied`) e spawna o próximo veículo automaticamente na vaga 2 livre (`vec4(225.80, -803.50, 30.6, 140.0)`), sem colisões nem empilhamento!
6. **Teste de Bloqueio de Veículo Já Fora (Anti-Duplicação)**:
   - Com o carro retirado e rodando na cidade (`state = 0`), volte ao atendente da garagem e abra o menu.
   - Observe o card desse veículo:
     - Badge amarela: **"Na Rua / Em Uso"**.
     - Botão bloqueado: **"🔒 JÁ FORA (EM USO)"**.
   - **Resultado Esperado**: É impossível duplicar o veículo retirando-o novamente. O servidor bloqueia tentativas com aviso: *"Este veículo já está fora da garagem!"*.

---

### 🔹 Teste 3: Restrições de Garagens de Empresa (Job/Gangue) & Blips Dinâmicos
1. **Teste Sem Permissão (Cidadão Comum)**:
   - Sem pertencer à corporação da polícia, vá até a Garagem LSPD (`coords: 441.10, -981.20, 30.6`).
   - Observe o NPC policial configurado individualmente (`s_m_y_cop_01`).
   - Tente interagir com ele para abrir a garagem.
   - **Resultado Esperado**:
     - Notificação vermelha imediata e clara de permissão: **"Você não possui permissão para acessar esta garagem."** (sem confundir com mensagem de 'nenhum veículo encontrado').
2. **Teste dos Blips Dinâmicos no Mapa**:
   - Abra o mapa do jogo (`ESC` -> Mapa).
   - Como cidadão comum:
     - As garagens públicas aparecem no mapa com seus nomes próprios (ex.: *"Garagem Central - Praça Legion"*, *"Marina de Los Santos"*).
     - A garagem privada da LSPD e a da facção Vagos **NÃO** aparecem no mapa para cidadãos sem permissão.
3. **Teste com Cargo Liberado**:
   - Dê a si mesmo o emprego de policial: `/setjob [id] police 1`.
   - **Resultado Esperado**:
     - Imediatamente o blip da LSPD (escudo azul `#60`, cor `#38`) surge no mapa.
     - Interaja com o NPC da LSPD: a garagem abre normalmente liberando os veículos da corporação.
4. **Teste de Gangue**:
   - Defina seu cargo como membro dos Vagos: `/setgang [id] vagos 1`.
   - O blip da garagem dos Vagos surge no mapa e o atendente (`g_m_y_salvagoon_01`) libera o acesso.

---

### 🔹 Teste 4: Como Guardar o Veículo (Área Demarcada de 4 Pontos + 5s)
O sistema utiliza **Áreas Poligonais Invisíveis de 4 Pontos** (`dropZone.points`), fechando uma área retangular/poligonal exata para a garagem sem desenhar nada no asfalto (imersão limpa, sem poluição visual 3D).

1. **Método 1: Pela Tecla [E] no Volante (Dentro dos 4 Pontos)**:
   - Estacione com o veículo dentro da área delimitada pelos 4 pontos.
   - Assim que o veículo entra no perímetro da vaga, surge o aviso flutuante: **`[E] Guardar Veículo na [Nome da Garagem]`**.
   - Pressione **[E]**.
3. **Método 2: Pelo Atendente NPC (ox_target)**:
   - Pare o veículo dentro do lote delimitado pelos 4 pontos da garagem e desça a pé.
   - Mire com `ox_target` no atendente e selecione **"Guardar Veículo (Vaga de Devolução)"**.
   - *Validação Geométrica*: Se o carro estiver fora da área dos 4 pontos, o atendente recusa: *"Nenhum veículo seu foi encontrado na vaga de devolução desta garagem. Estacione o veículo na área demarcada para guardá-lo."*
4. **Fluxo de Desembarque e Contagem Regressiva (5 Segundos)**:
   - Assim que acionado (seja por [E] ou pelo NPC):
     1. **Desembarque Automático**: O motorista e todos os passageiros presentes no veículo executam a animação de abrir a porta e descer do carro (`TaskLeaveVehicle`).
     2. **Segurança**: O motor desliga, as portas são trancadas e as luzes piscam.
     3. **Temporizador de 5 Segundos**: Uma barra de progresso elegante surge: `Inspecionando e guardando veículo...` durante **5 segundos**.
     4. **Armazenamento Seguro**: Após os 5 segundos, todas as propriedades e amassados do veículo são salvos no banco de dados e ele desaparece com notificação: *"Veículo [PLACA] guardado na [Nome da Garagem] com sucesso!"*.
5. **Ferramenta de Criação de Novas Vagas (/garagemzone)**:
   - Para definir 4 novos pontos no mapa para qualquer garagem:
     - Vá até o 1º canto e digite `/garagemzone add`
     - Vá até o 2º canto e digite `/garagemzone add`
     - Vá até o 3º canto e digite `/garagemzone add`
     - Vá até o 4º canto e digite `/garagemzone add`
     - O sistema fecha a caixa no chão ao vivo e imprime no console **F8** o bloco Lua pronto formatado para você apenas colar no `config.lua`!
     - Para reiniciar: `/garagemzone clear` | Para reimprimir: `/garagemzone print`.

---

### 🔹 Teste 5: Marcação de Garagens no GPS
1. **Pelo Comando `/garagens`**:
   - Em qualquer ponto do mapa, digite:
     ```text
     /garagens
     ```
   - **Resultado Esperado**:
     - Abre um menu contextual elegante (`ox_lib Context Menu`) intitulado **"📍 Garagens de Los Santos"**.
     - Lista todas as garagens que você tem acesso com ícones específicos (carro, barco, helicóptero, polícia, pátio) e a distância exata em metros.
     - Clique em qualquer uma: uma notificação confirma e o GPS traça a rota direta até o local no minimapa!
2. **Pela NUI `/listarveiculos`**:
   - Abra `/listarveiculos`.
   - Em qualquer veículo que esteja guardado em uma garagem física, clique no botão azul **"📍 MARCAR GARAGEM"** (ou no ícone de localização no card).
   - **Resultado Esperado**: O GPS marca a localização daquela garagem no mapa.

---

### 🔹 Teste 6: Menu Meus Veículos (`/listarveiculos`) — Regra de Retirada & Reboque
1. Execute `/listarveiculos` no chat.
2. **Resultado Esperado**:
   - Abre o modal geral com todos os seus veículos cadastrados no servidor.
3. **Teste de Regra de Spawning & Veículos Retidos**:
   - **Veículo Guardado em Garagem Fixa**:
     - O botão de ação é **`📍 MARCAR GARAGEM`**.
     - Não é possível spawnar o veículo na sua frente pela lista geral! O jogador deve ir até a garagem física onde o carro se encontra.
   - **Veículo Retido em Empresa/Gangue Sem Acesso (Demissão / Perda de Cargo)**:
     - Badge âmbar: **`SEM ACESSO`**.
     - O botão de ação é **`🚚 REBOCAR P/ CENTRAL ($500)`**.
     - Ao clicar, o sistema debita $500 do banco ou dinheiro do jogador, transfere o veículo para a Garagem Central (Praça Legion) e traça a rota GPS para a Central no minimapa!
   - **Veículo Estacionado na Rua (`/estacionar`)**:
     - O botão de ação é **`🔑 RETIRAR (RUA)`** e o ícone de localização marca a rua onde o carro ficou.
     - Ao clicar em `RETIRAR (RUA)`, o carro é trazido da vaga de rua com sucesso.
   - **Veículo Já Fora / Em Uso**:
     - Botão desabilitado: **`🔒 EM USO NA RUA`**.
   - **Veículo Apreendido**:
     - Botão azul: **`📍 IR AO IMPOUND`** (marca o Pátio no GPS).

---

### 🔹 Teste 7: Estacionamento Dinâmico de Rua (`/estacionar`)
1. Pare em qualquer rua do mapa como motorista e digite `/estacionar`.
2. **Resultado Esperado**:
   - Exibe confirmação com taxa de $250 para novos pontos.
   - Ao confirmar, o valor é debitado, o veículo tranca as portas e despawna após 60 segundos para otimização de memória.
3. Retorne à mesma vaga (raio de 10m) e digite `/estacionar`: **Gratuito ($0)**.
4. Para retomar o carro na rua: Aproxime-se a pé (raio de 3m) e pressione **[E]**. As portas destrancam e as chaves são devolvidas.
5. Trava Offline: Se o dono estiver offline, terceiros que tentarem arrombar são bloqueados e a polícia recebe chamado de alarme (`🚨 Alarme - Veículo Protegido`).

---

### 🔹 Teste 8: Deletar e Guardar na Garagem Mais Próxima (`/dv`)
1. Dentro de um veículo próprio em qualquer localidade da cidade, execute `/dv` ou `/deleteveh`.
2. **Resultado Esperado**:
   - O veículo salva customizações, lataria e motor, é deletado da rua e transferido para a garagem física mais próxima por cálculo de distância 3D.
   - Notificação: `"Veículo [PLACA] guardado na garagem mais próxima (Nome da Garagem)."`

---

### 🔹 Teste 9: Parquímetros Públicos & Tickets no Ox_Inventory
1. Vá até qualquer parquímetro nativo ou customizado (`coords: 232.11, -770.14, 30.6`).
2. Mire com `ox_target`:
   - **"Ver Status do Parquímetro"**: Informa se está pago ou vencido.
   - **"Pagar Parquímetro (1h - $50)"**: Debita $50 e entrega o item `parking_ticket` no `ox_inventory` com metadata detalhado.
   - **"Pagar Parquímetro (10h - $500)"**: Estende o comprovante em 10 horas.
   - **"Fiscalizar Parquímetro (Polícia)"**: Animação de prancheta de 3s e relatório detalhado com tempo restante, nome e telefone do pagador.

---

### 🔹 Teste 10: Fiscalização Policial, Multas & Apreensão de Veículos (Impound)
1. Como policial (`/setjob [id] police 1`), mire com `ox_target` em um veículo:
   - **"Multar Estacionamento Irregular"**: Aplica multa de $500 debitando da conta bancária do dono do veículo.
   - **"Apreender Veículo (Impound)"**: Abre diálogo `lib.inputDialog` para informar valor da multa, tempo de retenção (minutos) e motivo. O veículo é removido da rua e enviado ao pátio do Impound.
2. Comando Policial: `/apreender [PLACA] 500 5 "Estacionamento Proibido"`.

---

### 🔹 Teste 11: Pátio de Apreensão Policial (Impound Lot) & Liberação Bancária
1. Vá até o **Pátio de Apreensão Policial** (`coords: 409.12, -1623.55, 29.3`).
2. Interaja com o atendente NPC valet (`s_m_y_valet_01`):
   - A NUI abre exibindo **apenas os veículos apreendidos** do jogador.
3. Se estiver com tempo de retenção ativo: Ao clicar em retirar, bloqueia informando quantos minutos faltam para cumprir a retenção.
4. Se o tempo zerou: Ao clicar em retirar, a multa é debitada da conta bancária (`bank`), o registro é limpo e o veículo surge em uma das vagas livres do pátio com as chaves entregues.

---

### 🔹 Teste 12: Rastreador GPS Veicular & Jammer de Sinal (Com Imagens Oficiais)
1. Pegue o item `vehicle_tracker`: `/giveitem [id] vehicle_tracker 1`.
   - Abra o inventário: O item possui **ícone oficial** (`vehicle_tracker.png`).
   - Use o item próximo ao seu veículo: Barra de progresso de 5s instala o rastreador permanente no banco de dados (`haze_vehicle_trackers`).
2. Pegue o item `tracker_jammer`: `/giveitem [id] tracker_jammer 1`.
   - Abra o inventário: O item possui **ícone oficial** (`tracker_jammer.png`).
   - Use o item no veículo: Bloqueia o sinal do GPS por 30 minutos.
3. Validação: `exports['haze_garages']:IsTrackerInstalled('PLACA')` e `IsTrackerJammed('PLACA')`.

---

### 🔹 Teste 13: App de Garagem no Telefone (`vp_phone` & `/garagemapp`)
1. Abra o telefone no jogo ou digite `/garagemapp` para abrir o preview móvel.
2. Botão **Atualizar (`fas fa-sync-alt`)**: Recarrega veículos em tempo real.
3. Campo de Busca: Filtra por modelo, placa ou apelido.
4. Tags de Rastreador:
   - Cinza: *"Sem Rastreador GPS"* (Botão Rastrear desabilitado).
   - Amarela: *"Sinal GPS Bloqueado (Jammer)"* (Botão Rastrear desabilitado).
   - Verde: *"GPS Ativo"* (Botão Rastrear habilitado).
5. Botão **"Rastrear"**: Traça rota direta no mapa até o carro.
6. Botão **"Valet"**: Dispara recolhimento da garagem.

---

### 🔹 Teste 14: Persistência de Danos Mecânicos, Lataria 3D & Auto-Salvamento
1. Danifique o motor e amasse a lataria batendo em postes.
2. Guarde o veículo (via atendente, `/guardar` ou `/dv`) e retire-o novamente.
3. **Resultado Esperado**: O motor, óleo, combustível e cada amassado poligonal 3D permanecem exatamente iguais.
4. Ao reiniciar o servidor ou parar o resource (`restart haze_garages`): Todos os carros ativos de jogadores na rua são salvos e guardados na garagem pública mais próxima (`auto-store`), prevenindo perdas ou bugs.

---

## 🔍 Resumo de Comandos Rápidos para Testes

| Comando | Parâmetros | Descrição |
| :--- | :--- | :--- |
| `/listarveiculos` | Nenhum | Abre o menu geral de veículos |
| `/guardar` | Nenhum | Guarda o veículo na garagem física mais próxima |
| `/garagens` | Nenhum | Lista todas as garagens e permite marcar no GPS |
| `/estacionar` | Nenhum | Estaciona dinamicamente na rua |
| `/garagemapp` | Nenhum | Abre o preview do App de Garagem do celular |
| `/dv` | `[raio]` (opcional) | Deleta e guarda veículo próprio na garagem mais próxima |
| `/apreender` | `[placa] [multa] [tempo] [motivo]` | Comando policial para apreender veículos |
| `/setjob` | `[id] police 1` | Define emprego para testar funções policiais |
| `/setgang` | `[id] vagos 1` | Define gangue para testar garagem dos Vagos |
| `/garagemzone` | `add / clear / print` | Cria e gera código Lua dos 4 pontos de qualquer vaga no mapa |

---

*Haze Studios © 2026. Homologado para QBox Framework & Overextended Stack.*
