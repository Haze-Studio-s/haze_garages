# 🧪 Guia Completo de Testes & Validação de QA — `haze_garages`

Este documento é o **guia oficial de testes passo a passo** para homologação do recurso **`haze_garages`** e contém o histórico das correções aplicadas.

---

## 📋 Checklist de Pré-requisitos (Antes de Iniciar os Testes)

- [x] O resource `haze_garages` está em `resources/[ai_create]/haze_garages`.
- [x] O arquivo `server.cfg` contém `ensure haze_garages`.
- [x] O item `parking_ticket` está registrado no `ox_inventory/data/items.lua`.
- [x] O banco de dados MySQL (`oxmysql`) está rodando normalmente com auto-migration de tabelas.

---

## 🧪 Roteiro de Testes Passo a Passo (`haze_garages`)

### 🔹 Teste 1: Boot Automático & Inicialização de Banco de Dados
1. Inicie ou reinicie o recurso no console do servidor:
   ```cmd
   restart haze_garages
   ```
2. **Resultado Esperado**:
   - Log verde no console: `^2[Haze Garages]^7 Tabelas de banco de dados inicializadas e verificadas com sucesso.`
   - Tabelas criadas/verificadas no banco: `haze_street_parking`, `haze_fixed_garages`, `haze_parking_meters`, `haze_vehicle_deformations`, `granolla_vehicle_wear`.

---

### 🔹 Teste 2: Garagens Fixas & Atendente Ped NPC
1. Dirija-se à Garagem Central da Praça Legion (`coords: 215.12, -810.55, 30.7`).
2. Observe o NPC atendente (`a_m_y_business_01`) spawnado no local.
3. Mire no NPC com `ox_target` ou pressione `[E]` ao se aproximar.
4. **Resultado Esperado**:
   - Interface NUI ou menu abre exibindo seus veículos salvos.
   - Ao selecionar e spawnar um carro, ele surge na vaga (`spawnCoords: 222.10, -805.20, 30.6`), as chaves são concedidas via `qbx_vehiclekeys` e o jogador pode entrar e dirigir.


---

### 🔹 Teste 3: Restrições de Acesso (Corporativo & Gangue)
1. Como um cidadão comum (sem job de polícia), vá até a Garagem LSPD (`police_main`).
2. Tente acessar a garagem.
3. **Resultado Esperado**: O acesso é bloqueado com notificação de "Sem permissão".
4. Defina seu job como `police` (`/setjob [id] police 1`) e interaja novamente.
5. **Resultado Esperado**: Garagem liberada para uso corporativo.

---

### 🔹 Teste 4: Comando de Menu Geral `/listarveiculos`
1. Execute o comando `/listarveiculos` no chat.
2. **Resultado Esperado**:
   - Menu contextual `ox_lib` abre listando todos os seus veículos cadastrados no servidor sem erros de SQL ou Collation.
   - Exibe status ("Garagem Legion", "Estacionado na Rua", "Em Uso", "Apreendido").
   - Exibe saúde do motor, lataria, combustível, quilometragem e peças do `granolla_mechanic` (velas, freios, óleo, etc.).
3. Se um carro estiver estacionado na rua distante, clique nele no menu.
   - **Resultado Esperado**: O GPS marca o ponto exato da rua onde o carro está localizado.
4. Se o carro estiver guardado em uma garagem próxima, clique em "Retirar / Spawn".
   - **Resultado Esperado**: Confirmação visual e spawn imediato do veículo.

---

### 🔹 Teste 5: Estacionamento Dinâmico de Rua (`/estacionar`)
1. **Ponto Novo (1ª Vez)**: Entre em um veículo de sua propriedade, pare em qualquer rua e digite `/estacionar`.
   - **Resultado Esperado**: Exibe aviso de cobrança de taxa de $250. Ao confirmar, o valor é debitado, a vaga é salva e o veículo físico despawna da tela em exatamente 60 segundos.
2. **Retorno ao Mesmo Ponto**: Pegue o carro, dê uma volta curta e estacione de novo no mesmo local (raio de 10 metros).
   - **Resultado Esperado**: **Gratuito!** Notifica que é sua vaga cadastrada e não cobra taxa.
3. **Troca de Vaga de Rua**: Dirija para outro bairro (> 10m) e digite `/estacionar`.
   - **Resultado Esperado**: Atualiza sua vaga de rua para o novo local e cobra a taxa de $250.
4. **Trava de Dono Offline com Chamado Policial**: Estacione na rua, deslogue do servidor. Peça a outro jogador para tentar arrombar/usar o veículo.
   - **Resultado Esperado**:
     - Veículo bloqueado com mensagem **"Veículo protegido contra arrombamentos"**.
     - Dispara automaticamente um chamado policial no mapa/dispatch com alerta de alarme e localização exata.

---

### 🔹 Teste 6: Parquímetros & Interação Visual no Target
1. Vá até qualquer parquímetro nativo no mapa ou customizado (`prop_parkstat_01`).
2. Mire com `ox_target` no parquímetro.
3. **Resultado Esperado**:
   - Se o parquímetro NÃO estiver pago, mostra no target **"🔴 Parquímetro NÃO PAGO"**.
   - Ao selecionar **"Pagar Parquímetro (1h - $50)"**, $50 são debitados e o jogador recebe o item `parking_ticket` no inventário com metadados do pagador e validade.
   - Ao mirar novamente no parquímetro pago, o target passa a exibir diretamente **"🟢 Parquímetro PAGO (Ver Tempo)"** informando os minutos restantes.

---

### 🔹 Teste 7: Fiscalização Policial com Progressbar & Notificação Completa
1. Mude seu cargo para policial (`/setjob [id] police 1`).
2. Mire com `ox_target` em um parquímetro e selecione **"Fiscalizar Parquímetro (Polícia)"**.
3. **Resultado Esperado**:
   - Uma barra de progresso (`lib.progressBar`) de 3 segundos é exibida com animação de prancheta.
   - Ao concluir, uma notificação detalhada é exibida por 10 segundos na tela contendo:
     - Status da vaga (Válido ou Vencido)
     - Tempo restante em minutos
     - **Nome completo do pagador**
     - **Número de telefone do pagador**
4. Mire com `ox_target` em um veículo cujo tempo do parquímetro expirou e escolha **"Multar Estacionamento Irregular"**.
   - **Resultado Esperado**: Emite multa de $500 debitando da conta bancária do dono do veículo.

---

### 🔹 Teste 8: Persistência de Lataria 3D & Danos Mecânicos
1. Danifique o motor de um carro (deixe a 40%) e amasse a lataria batendo em postes.
2. Guarde o veículo na garagem ou estacionar na rua.
3. Retire o veículo novamente.
4. **Resultado Esperado**: Os amassados específicos da lataria 3D e o nível reduzido do motor permanecem exatamente idênticos ao momento em que foi guardado.

---

### 🔹 Teste 9: Remoção de Veículo com Envio Automático para Garagem Mais Próxima (`/dv` / `/deleteveh`)
1. Spawne ou pegue um veículo de sua propriedade em qualquer parte do mapa (ex: próximo a Legion Square, Pillbox ou delegacia).
2. Entre no veículo ou fique próximo a ele (raio até 5m) e execute o comando `/dv` ou `/deleteveh`.
3. **Resultado Esperado**:
   - Se o veículo pertence a um jogador (`player_vehicles`), suas propriedades (customizações, danos, combustível) são salvas.
   - O estado do veículo é atualizado para `state = 1` (guardado) e vinculado à **garagem fixa mais próxima por distância 3D**.
   - Se o veículo estava cadastrado em vaga de rua (`haze_street_parking`), o registro de rua é limpo.
   - Uma notificação é exibida: `"Veículo [PLACA] guardado na garagem mais próxima (Nome da Garagem)."`
   - Ao ir até a garagem indicada no aviso e abrir o menu, o veículo estará disponível para retirada em perfeito estado.
   - Se o veículo for de NPC/ambiente, ele é deletado exibindo `"Veículo [PLACA] deletado."`

---

### 🔹 Teste 10: Apelidos de Veículos (Nicknames) & NUI `/listarveiculos` (Lation Emerald)
1. Execute `/listarveiculos` no chat.
2. **Resultado Esperado**:
   - Abre a **NUI Lation Modern UI Modal** (Emerald Edition) com a barra de rolagem customizada escura (sem a barra nativa branca do navegador).
   - Exibe a lista completa de veículos com barra de busca por texto em tempo real (filtrando por modelo, placa ou apelido).
3. Clique no botão de editar apelido (`✏️`) ao lado de um veículo.
4. Digite um apelido (ex: *"Meu Adder de Corrida"*) e clique em **"SALVAR"**.
5. **Resultado Esperado**:
   - Notificação de confirmação e tag visual verde exibidida ao lado do nome do veículo (`[tag: Meu Adder de Corrida]`).
   - O apelido permanece salvo no banco de dados (`haze_vehicle_nicknames`) e persiste mesmo após fechar a NUI, relogar ou reiniciar o script.
6. Em um veículo estacionado na rua, clique no botão de rastreamento (`📍`).
   - **Resultado Esperado**: Marca o ponto exato no GPS do mapa.

---

*Haze Studios © 2026.*


