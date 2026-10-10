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

### 🔹 Teste 15: Criador In-Game & Gerenciador de Garagens (/criargaragem & /gerenciargaragens)
O sistema conta com um assistente guiado completo para criar e gerenciar garagens 100% in-game com gravação física imediata em `data/garages.json` e hot-reload via broadcast para todos os jogadores sem reiniciar o servidor.

1. **Permissão Administrativa**:
   - O comando valida permissões administrativas (`group.admin`, ACE FiveM, QBX Core, QBCore ou ESX).
   - Jogadores sem permissão recebem aviso de bloqueio no chat/notificação.

2. **Passo a Passo de Criação (/criargaragem ou /novagaragem)**:
   - Digite `/criargaragem` no chat.
   - **Passo 1 (Formulário ox_lib)**: Preencha ID único (ex: `shopping_central`), Nome visível, Tipo (`public`, `job`, `gang` ou `impound`), Job/Gangue se aplicável, Categoria (`car`, `boat`, `air`), Modelo do Ped NPC e Blip.
   - **Passo 2 (NPC Atendente)**: Fique em pé na posição e direção desejada para o atendente NPC e pressione **`[E]`**.
   - **Passo 3 (Área de Devolução - 4 Cantos)**: Caminhe até cada um dos 4 cantos da área de devolução e pressione **`[E]`** em cada um. Marcadores temporários orientam o admin durante a marcação e desaparecem completamente ao concluir (o asfalto permanece 100% limpo).
   - **Passo 4 (Vagas de Saída)**: Posicione-se (a pé ou no veículo) nas vagas de spawn desejadas e pressione **`[E]`** para cada vaga. Pressione **`[G]`** para concluir.
   - **Passo 5 (Confirmação)**: Um resumo é exibido via diálogo. Ao confirmar, o arquivo `data/garages.json` é gravado fisicamente no disco e a garagem entra em funcionamento instantaneamente no mapa para todos os jogadores!

3. **Painel de Gerenciamento & Edição (/gerenciargaragens ou /garagensadmin)**:
   - Digite `/gerenciargaragens`.
   - Um menu contextual exibe a lista de todas as garagens cadastradas no servidor, além dos botões de ação globais:
     - **`[+] Criar Nova Garagem`**: Abre o assistente de criação guiada.
     - **`[🔄] Sincronizar / Recarregar do Disco`**: Lê o arquivo `data/garages.json` e sincroniza instantaneamente com todos os jogadores sem reiniciar o servidor.
   - Ao selecionar qualquer garagem da lista, o submenu disponibiliza:
     - **📍 Teleportar até a Garagem**: Leva o admin diretamente às coordenadas do atendente NPC.
     - **ℹ️ Ver Detalhes e Coordenadas**: Abre relatório técnico detalhado com IDs, blips, espessura da zona, coordenadas dos 4 cantos e todas as vagas de spawn registradas.
     - **✏️ Editar Informações Básicas**: Abre formulário com dados atuais pré-preenchidos para alterar nome, tipo (pública/job/gangue/impound), categoria, modelo do NPC ou ícone/cor do blip mantendo os pontos demarcados intactos.
     - **🚶 Re-posicionar Atendente NPC**: Permite ao admin ficar de pé no novo local desejado e pressionar **`[E]`** para atualizar a posição e ângulo do atendente sem precisar refazer as vagas.
     - **🗑️ Excluir Garagem**: Remove a garagem permanentemente do arquivo `data/garages.json` e a desativa em tempo real no servidor após confirmação.

4. **Teste de Hot-Reload em Tempo Real (Zero Restart)**:
   - Crie uma garagem com `/criargaragem`, edite uma com `/gerenciargaragens` ou exclua uma.
   - Observe o console F8 do cliente: `[Haze Garages] Hot-reload executado com sucesso: X garagens ativas sem restart.`
   - Todos os peds antigos, pontos de lib e blips são limpos de forma atômica (`removeLocalEntity`, `pt:remove()`, `RemoveBlip()`).
   - A nova malha de entidades e zonas é reconstruída instantaneamente sem nenhum restart no servidor e mantendo o resmon constante em 0.00ms.

---

### 🔹 Teste 15: Valet com Manobrista NPC Dirigindo até Você (Fase 1)
1. **Solicitação via Celular ou Comando**:
   - Abra o App do Celular (`/garagemapp` ou pelo `vp_phone`) ou use o comando `/valet [placa]`.
   - Se digitar apenas `/valet`, um menu modal do `ox_lib` lista todos os seus veículos atualmente guardados (`state = 1`) com nome, placa, garagem de origem e taxa de serviço ($150).
2. **Validações de Bloqueio**:
   - Tente solicitar o valet de um veículo que já está fora na rua (`state = 0`): deve recusar com notificação: *"Este veículo já está fora da garagem (em uso na rua)! Não é possível chamar o manobrista."*
   - Tente solicitar o valet de um veículo apreendido no Impound (`state = 2`): deve recusar com notificação de retenção policial.
   - Tente solicitar enquanto você estiver dentro de um carro: deve recusar solicitando que você desça do veículo.
3. **Despacho & Trajeto do NPC no Trânsito Real**:
   - O servidor localiza a garagem pública mais próxima de onde você está (`category == 'car'`).
   - O veículo spawna na vaga livre da garagem com o NPC Manobrista uniformizado (`s_m_m_valet_01`) ao volante.
   - Um blip amarelo móvel é criado no radar com o texto `Valet a Caminho: [PLACA]`.
   - As portas do veículo são trancadas contra furto de estranhos.
   - O manobrista pilota o veículo respeitando as regras de trânsito e semáforos (`drivingStyle = 786603`) até onde você está.
4. **Chegada, Parada no Meio-Fio e Entrega de Chaves**:
   - Ao se aproximar a menos de ~18 metros de você, o manobrista desacelera e encosta no meio-fio (`BringVehicleToHalt`).
   - O veículo para suavemente, puxa freio de mão, liga pisca-alerta e destranca as portas.
   - O manobrista abre a porta, sai do veículo e caminha diretamente até você na calçada.
   - Ao se aproximar a 1.8 metros, ele se posiciona de frente para você e toca a animação de entrega de chaves com prop nativo de chaves na mão (`mp_common:givetake2_a`).
   - Notificação em tela: *"Aqui estão as chaves do seu veículo, senhor! Tenha uma excelente viagem."*
   - As chaves são sincronizadas automaticamente com o `qbx_vehiclekeys`.
   - O manobrista despede-se e vai embora a pé tranquilamente pela calçada (`TaskWanderStandard`).

---

### 🔹 Teste 16: Gestão Avançada para Corporações (Fase 2)
1. **Restrição por Patente Mínima (minGrade)**:
   - Defina seu emprego para recruta: `/setjob [seu_id] police 0`.
   - Acesse a Garagem da Polícia (`police_main`).
   - Observe que a viatura patrulha comum (`police`) aparece com botão verde `RETIRAR`.
   - Observe que viaturas de alto escalão (`corvette` minGrade 3 e `riot` Bearcat minGrade 4) aparecem bloqueadas com botão cinza `PATENTE MÍNIMA (3+)` ou `PATENTE MÍNIMA (4+)`.
   - Tente retirar a Corvette: a retirada é impedida autoritativamente pelo servidor com notificação: *"Patente insuficiente! Esta viatura exige patente mínima 3 (sua patente atual: 0)."*
   - Promova-se a Capitão: `/setjob [seu_id] police 3`.
   - Reabra a garagem: a Corvette agora aparece liberada com botão verde `RETIRAR`!
2. **Livro de Bordo / Histórico de Uso (Logs da Corporação)**:
   - Retire uma viatura liberada (ex: `police` ou `corvette`).
   - No topo do menu da garagem, clique no botão esmeralda `📋 LIVRO DE BORDO` ou digite `/livrodebordo`.
   - Verifique o modal Lation Emerald:
     - Tabela exibe o registro em tempo real:
       - **Data/Hora**: timestamp formatado.
       - **Ação**: `🟢 Retirada`.
       - **Condutor**: Seu nome de personagem + CitizenID.
       - **Viatura/Placa**: Modelo e placa da viatura retirada.
       - **Combustível**: Percentual inicial (100%).
       - **Integridade**: Tag verde `Intacto (100% M / 100% L)`.
3. **Auditoria de Devolução & Registro de Danos / Amassados**:
   - Dirija a viatura, colida contra um poste para amassar a lataria (`bodyHealth < 800`) e gaste um pouco de combustível.
   - Devolva a viatura na vaga da garagem com `[E]`.
   - Abra o Livro de Bordo novamente:
     - Uma nova linha com ação `🔴 Devolução` foi registrada automaticamente!
     - A coluna de integridade agora exibe o selo em amarelo/laranja `Avariado` ou vermelho `Crítico` indicando com precisão a porcentagem de danos deixada pelo último condutor.
     - A coluna de combustível reflete o nível exato com que o carro foi deixado no pátio.
4. **Controle de Acesso Hierárquico aos Logs**:
   - Mude sua patente para Recruta (`police 0`): o botão `📋 LIVRO DE BORDO` fica oculto e o comando `/livrodebordo` é bloqueado com notificação de patente insuficiente. Apenas Oficiais Superiores (patente 2+) têm permissão de auditoria.

---

### 🔹 Teste 17: Sistema de Coproprietário / Condutor Autorizado (Fase 3)
1. **Cadastro de Condutor Autorizado ($1.000)**:
   - Abra o menu da garagem física (`/listarveiculos` ou no atendente) ou o App do Celular (`/garagemapp`).
   - No card de qualquer veículo de sua propriedade exclusiva, observe o novo botão com ícone de amigos: **`👥 Condutor`** ou **`👥 Gerenciar Condutor`**.
   - Ou digite `/condutor [PLACA]` (ou estando dentro do veículo, apenas `/condutor`).
   - Um diálogo `ox_lib.inputDialog` solicita o ID do jogador (Server ID ou CitizenID).
   - Ao confirmar: A taxa única de serviço de **$1.000** é debitada da sua conta bancária (`bank` ou `cash`), e o jogador recebe notificação imediata em tempo real informando que agora é condutor autorizado do veículo.
2. **Limite Estrito de 1 Condutor por Veículo**:
   - Tente adicionar um segundo condutor ao mesmo veículo: O sistema bloqueia informando que o veículo já possui um condutor autorizado cadastrado e orienta a revogar o atual primeiro.
3. **Acesso Total com Proprietário Offline**:
   - Desconecte o personagem proprietário (ou teste com o CitizenID dele).
   - O condutor autorizado vai até qualquer garagem pública onde o veículo esteja guardado, ou abre o App do Celular:
     - O veículo aparece na lista do condutor com o selo azul **`[AUTORIZADO]`**.
     - O condutor pode clicar em **`RETIRAR`** na garagem, dirigir normalmente e guardar de volta na garagem (`/guardar`).
     - O condutor pode solicitar **Valet** pelo celular para o carro ser entregue a ele!
4. **Revogação de Permissão (Gratuita)**:
   - O proprietário legítimo clica no botão de condutor ou executa `/condutor [PLACA]`.
   - Um diálogo exibe o nome e CitizenID do condutor ativo, com o botão **`❌ Revogar Autorização`**.
   - Ao confirmar, o vínculo é excluído imediatamente do banco de dados sem custo adicional.

---

### 🔹 Teste 18: Seguradora de Veículos Sinistrados (Mors Mutual - Fase 4)
1. **Detecção Autoritativa de Sinistro / Perda Total**:
   - Entre em um veículo próprio e provoque sua destruição (explodindo-o ou afundando-o na água do mar).
   - O sistema detecta a destruição, limpa o veículo da rua e marca o estado autoritativo como **`state = 3` (Sinistrado na Mors Mutual)**.
   - Notificação em tela: *"Seu veículo [PLACA] sofreu perda total! Uma ocorrência de sinistro foi aberta na Seguradora Mors Mutual."*
2. **Bloqueio em Garagens Comuns e Valet**:
   - Tente retirar o veículo destruído em qualquer garagem pública comum ou solicitar Valet:
     - Bloqueio imediato com aviso: *"Este veículo sofreu perda total e está na Seguradora Mors Mutual! Digite /seguro para acionar o resgate da apólice."*
3. **Acionamento de Sinistro & Franquia (Normal vs. Expresso)**:
   - Abra o App do Celular (`/garagemapp`), digite `/seguro` ou vá até o **Pátio da Seguradora Mors Mutual** (`coords: -834.8, -2354.2, 14.5`).
   - O veículo exibe o selo vermelho **`🚨 Sinistrado (Mors Mutual)`** com botão **`MORS MUTUAL`**.
   - Ao selecionar o veículo, você tem duas opções:
     - **⏱️ Acionamento Normal ($2.500)**: Debita a franquia base da sua conta bancária e coloca o veículo em reparo com **carência de 15 minutos**.
     - **⚡ Acionamento Expresso ($3.500)**: Paga a franquia + taxa de guincho emergencial de $1.000, restaurando e liberando o veículo **imediatamente sem carência**!
4. **Aceleração de Guincho em Andamento**:
   - Se você acionou a apólice normal e o carro está em carência:
   - Reabra o menu `/seguro`: Ele exibe o tempo restante em minutos e oferece o botão **`⚡ Liberar Imediatamente ($1.000)`** para converter em expresso a qualquer momento.
5. **Retirada do Veículo 100% Restaurado**:
   - Quando o tempo de carência acaba (ou na taxa expressa), o status muda para **`🟢 Pronto para Retirada`**.
   - Clique em **`Retirar Veículo`**:
     - O veículo sai com lataria polida, motor a 1000.0, combustível a 100% e todas as deformações limpas de volta à vida no pátio da Mors Mutual!

---

### 🔹 Teste 19: Garagens Dinâmicas Residenciais & Condomínios (`ps-housing` - Fase 5)
1. **Registro Dinâmico Automático**:
   - Ao carregar uma propriedade residencial unifamiliar ou condomínio multi-unidades no `ps-housing`, o evento server-side invoca `exports['haze_garages']:RegisterDynamicGarage(...)`.
   - **Resultado Esperado**:
     - A garagem fica disponível no servidor sem alterar ou sujar o `data/garages.json`.
     - Nenhum NPC fixo é spawnado na calçada da residência (clean visual).
     - Não cria blips públicos desnecessários no mapa de outros jogadores.
2. **Acesso por Proprietário e Co-Morador Autorizado**:
   - Aproxime-se da vaga da residência a pé ou em veículo.
   - TextUI elegante surge no canto: `[E] Garagem Residencial` ou `[E] Guardar Veículo`.
   - Abra a garagem (`[E]` ou via `ox_target` no condomínio):
     - Proprietário abre a interface Lation Emerald com sucesso.
     - Co-morador com permissão `garage` abre a interface com sucesso.
     - Cidadão sem chave / sem permissão recebe aviso de restrição de acesso.
3. **Privacidade Entre Moradores (Multi-Unidades / Condomínio)**:
   - Dois jogadores diferentes moram no mesmo prédio ou compartilham a casa.
   - Jogador A abre a garagem: visualiza apenas os carros que pertencem ao Jogador A (ou aos quais ele é condutor autorizado).
   - Jogador B abre a garagem: visualiza apenas os seus próprios carros.
   - **Resultado Esperado**: Nenhum morador vê nem mexe na frota alheia.
4. **Armazenamento e Proteção Anti-Teleporte**:
   - Entre na dropZone com o veículo e pressione `[E]` ou use o target:
     - O veículo é guardado no banco com estado `state = 1` e `garage = 'house_X'` / `building_Y`.
     - Se o jogador tentar forçar o evento de guardar a mais de 15 metros da vaga, o servidor rejeita com aviso anti-exploit.
5. **Interface NUI & Desativação de Valet**:
   - No card do veículo guardado na residência, a badge exibe a classe verde esmeralda `.status-residential`: `"Guardado na Residência"`.
   - Em garagens residenciais, a opção de Valet é desabilitada e exibe o botão rápido de GPS.
6. **Desregistro Dinâmico (Clean Lifecycle)**:
   - Se a propriedade for deletada, transferida ou se o `ps-housing` for reiniciado:
     - `exports['haze_garages']:UnregisterDynamicGarage(id)` é invocado, limpando zonas e dados da memória sem deixar pontos órfãos.

---

## 🔍 Resumo de Comandos Rápidos para Testes

| Comando | Parâmetros | Descrição |
| :--- | :--- | :--- |
| `/seguro` | Nenhum | Abre o painel de sinistros da Seguradora Mors Mutual (Franquia & Expresso) |
| `/condutor` | `[placa]` (opcional) | Gerencia o condutor autorizado/coproprietário do veículo ($1.000) |
| `/livrodebordo` | `[garageId]` (opcional) | Abre o Livro de Bordo corporativo com histórico de uso, condutores e avarias |
| `/valet` | `[placa]` (opcional) | Solicita manobrista NPC para trazer seu veículo da garagem pública mais próxima |
| `/listarveiculos` | Nenhum | Abre o menu geral de veículos |
| `/guardar` | Nenhum | Guarda o veículo na garagem física mais próxima |
| `/garagens` | Nenhum | Lista todas as garagens e permite marcar no GPS |
| `/criargaragem` | Nenhum | Inicia o Wizard de criação de garagens in-game (Admin) |
| `/gerenciargaragens` | Nenhum | Abre o menu de gerenciamento e teleporte/exclusão (Admin) |
| `/estacionar` | Nenhum | Estaciona dinamicamente na rua |
| `/garagemapp` | Nenhum | Abre o preview do App de Garagem do celular |
| `/dv` | `[raio]` (opcional) | Deleta e guarda veículo próprio na garagem mais próxima |
| `/apreender` | `[placa] [multa] [tempo] [motivo]` | Comando policial para apreender veículos |
| `/setjob` | `[id] police 1` | Define emprego para testar funções policiais |
| `/setgang` | `[id] vagos 1` | Define gangue para testar garagem dos Vagos |
| `/garagemzone` | `add / clear / print` | Cria e gera código Lua dos 4 pontos de qualquer vaga no mapa |

---

*Haze Studios © 2026. Homologado para QBox Framework & Overextended Stack.*
