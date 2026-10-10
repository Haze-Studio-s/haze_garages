# 🚗 haze_garages — Haze Studios

**haze_garages** é um sistema completo e otimizado de Garagens Fixas, Estacionamento Persistente de Rua (`/estacionar`) e Parquímetros Interativos com Fiscalização Policial desenvolvido para **QBox**, **QBCore** e **ESX**.

---

## 🛠️ Stack & Requisitos

- **Core / Framework:** `qbx_core` (1.23.0) / `qb-core` / `esx` (Detecção Automática via wrapper)
- **Bibliotecas:** `ox_lib` (>= 3.32.2), `ox_target`, `oxmysql`
- **Inventário:** `ox_inventory` (suporte ao item `parking_ticket` com metadata)
- **Chaves:** `qbx_vehiclekeys` / `qb-vehiclekeys`
- **Mecânica Integrada:** `granolla_mechanic` (leitura de desgaste de peças)
- **Interface NUI:** Lation Modern UI — Emerald Edition (`#10b981` / `#6afe87` / `#1e1f24`, fontes Inter e JetBrains Mono)

> 📖 **Guia Passo a Passo de Instalação:** Veja o arquivo [`instalacao/README.md`](file:///c:/Server%20Fivem%20Teste/resources/%5Bai_create%5D/haze_garages/instalacao/README.md) para registrar os itens do `ox_inventory`, ordem do `server.cfg` e comandos.

---

## ✨ Funcionalidades Principais

### 1. Estacionamento Persistente de Rua (`/estacionar`)
- **Estacionar em Qualquer Lugar:** Jogadores podem estacionar veículos diretamente na rua em qualquer coordenada do mapa.
- **Cobrança por Novo Ponto:** A primeira vez que um veículo estaciona em uma determinada vaga de rua, é cobrada uma taxa (`Config.StreetParkingFee = 250`).
- **Gratuidade no Mesmo Ponto:** Permanecer ou retornar à mesma vaga salva (dentro de `Config.DynamicSpotTolerance = 10.0m`) é totalmente gratuito.
- **Substituição de Vaga:** Ao mudar de local na rua, a vaga antiga é removida, a taxa é cobrada novamente e a nova vaga é registrada.
- **Suporte a VIP:** Permite definir limites de vagas simultâneas por grupo VIP em `Config.StreetParkVIPLimits` (`default: 1`, `vip_gold: 2`, `vip_diamond: 3`).
- **Expiração Automática para Garagem Mais Próxima:** Se uma vaga de rua atingir o limite de inatividade (`Config.StreetParkingExpirationHours = 72`), o veículo é recolhido e transferido automaticamente para a **garagem fixa mais próxima** da coordenada onde estava estacionado.
- **Proteção de Veículo Offline:** Se o proprietário do veículo estiver **offline**, o sistema bloqueia tentativas de arrombamento por itens de terceiros (ex: lockpick/hotwire). Apenas a chave original (`qbx_vehiclekeys`) destrava o veículo.

---

### 2. Garagens Fixas no Mapa (Sem Peds)
- **Tipos de Garagens:** Públicas, de Trabalho (`job: police`, `ambulance`, etc.) e de Gangues (`gang: vagos`, `ballas`, etc.).
- **Sem Peds / Com Props Elegantes:** Interações feitas por props (`prop_parkstat_01`) e marcadores `ox_target` para evitar problemas de animação/despawn de peds.
- **Prevenção de Duplicação (Anti-Dupe):** Sistema de `spawnReservations` que impede que requisições simultâneas ou lag dupliquem o spawn do mesmo veículo.

---

### 3. Parquímetros Interativos Pagos & Fiscalização Policial
- **Modelos Nativos & Customizados:** Suporte automático para os parquímetros nativos do GTA V (`prop_parkstat_01`, `prop_parkstat_02`, `prop_parkstat_03`, `prop_parkingpay_01`) e suporte para novos parquímetros em coordenadas customizadas (`Config.CustomParkingMeters`).
- **Item de Ticket no `ox_inventory`:** Ao pagar o parquímetro, o jogador recebe o item `parking_ticket` no inventário contendo metadata com placa, horário de emissão, validade e localização.
- **Fiscalização Policial (`ox_target`):** Policiais (`police`, `sheriff`) podem interagir com veículos e parquímetros para **"Fiscalizar Parquímetro"**, verificando a validade do ticket ou aplicando multas bancárias automáticas (`Config.PoliceFineAmount = 500`) em caso de infração.

---

### 4. Interface NUI Lation Emerald & Odômetro Integrado (`granolla_mechanic`)
- **Design System:** Padrão visual moderno Lation Emerald Edition com painel lateral verde neon (`#10b981`), tipografia limpa (Inter + JetBrains Mono) e animações suaves.
- **Odômetro Real & Milhagem Percorrida:** Integração direta com a tabela `granolla_vehicle_wear` e os exports do `granolla_mechanic`, exibindo a milhagem percorrida no card do veículo (`1.450,2 mi`) com barra de progresso em gradiente esmeralda neon.
- **Sincronização de State Bag:** Ao retirar o carro da garagem, o `haze_garages` injeta o valor no state bag `Entity(veh).state.vehicleMileage`, permitindo que o HUD de odômetro do mecânico continue a contagem sem perder dados.
- **Integração Mecânica Completa:** Exibe a saúde em tempo real de Motor, Lataria, Tanque e Desgaste de Peças (suspensão, freio, embreagem, injetores) direto nas barras de status da NUI e no App do Celular (`vp_phone` / `/garagemapp`).
- **Deformação Física:** Armazena e restaura a deformação real dos vértices da carcaça do veículo ao retirar da garagem.

---

### 5. Caching & Spatial Grid Streaming
- **Sem Broadcasts Globais:** Veículos de rua são carregados usando Spatial Grid Streaming via `ox_lib.points` em um raio de 60 metros. Jogadores distantes não processam veículos desnecessários.
- **Criação Automática do Banco de Dados:** Executa comandos `CREATE TABLE IF NOT EXISTS` no evento `MySQL.ready` para criar as tabelas `haze_street_parking`, `haze_fixed_garages`, `haze_parking_meters` e `haze_vehicle_deformations` sem necessidade de importar arquivos SQL manualmente.

---

### 6. Garagens Dinâmicas Residenciais (Integração `ps-housing`)
- **Registro em Tempo Real:** Recursos externos (como `ps-housing` para casas e condomínios) registram e removem garagens dinâmicas em tempo de execução via exports sem alterar `data/garages.json`.
- **Controle de Acesso Fino:** Callback server-side `canAccess(source, garage)` permitindo que proprietários e co-moradores com permissão concedida usem a garagem.
- **Privacidade Entre Moradores:** Em condomínios ou casas compartilhadas, cada morador visualiza unicamente os veículos que possui ou aos quais tem autorização direta.
- **Proteção Anti-Teleporte & Fallback:** Validação de proximidade rígida na dropZone para impedir exploits e teleporte indevido. Fallback universal de raio de 6.0 metros para vagas dinâmicas.
- **Interface Lation Emerald Adaptada:** Badge visual `.status-residential` ("Guardado na Residência"), desativação de Valet em garagens residenciais e botão de rota GPS rápida.
- **Exports Disponíveis:**
  - **Server:**
    - `exports['haze_garages']:RegisterDynamicGarage(garageData)`: Registra garagem residencial ou de condomínio.
    - `exports['haze_garages']:UnregisterDynamicGarage(garageId)`: Remove garagem e limpa pontos ativos.
    - `exports['haze_garages']:IsDynamicGarage(garageId)`: Retorna se a garagem é dinâmica.
  - **Client:**
    - `exports['haze_garages']:OpenGarageMenu(garageId)`: Abre o menu da garagem especificada via NUI.
    - `exports['haze_garages']:StoreVehicleAtGarage(garageId)`: Guarda o veículo atual na garagem.

---

## 📦 Configuração do Inventário (`ox_inventory`)

Adicione a seguinte definição de item ao arquivo `data/items.lua` do seu `ox_inventory`:

```lua
['parking_ticket'] = {
    label = 'Ticket de Parquímetro',
    weight = 10,
    stack = false,
    close = true,
    description = 'Comprovante de pagamento de parquímetro.',
    client = {
        image = 'parking_ticket.png',
    }
},
```

---

## 💻 Comandos

- `/estacionar`: Estacionar ou recolher o veículo atual na vaga de rua mais próxima / coordenada atual.

---

## 📁 Estrutura de Arquivos

```
haze_garages/
├── config.lua               # Configurações gerais (garagens, preços, vip, polícias)
├── fxmanifest.lua           # Manifest do resource FiveM (Lua 5.4)
├── README.md                # Documentação técnica oficial
├── TEST_GUIDE.md            # Guia completo de testes e validação
├── client/
│   ├── cl-main.lua          # Inicialização, neta/blips e loops de apoio
│   ├── cl-garage.lua        # Garagens fixas e NUI callback handlers
│   ├── cl-street-parking.lua# Estacionamento de rua, spatial grid e offline locks
│   ├── cl-parking-meters.lua# Target e compra em parquímetros
│   └── cl-deformation.lua   # Leitura/Aplicação de deformação física
├── server/
│   ├── sv-database.lua      # Boot automático do SQL (CREATE TABLE IF NOT EXISTS)
│   ├── sv-garage.lua        # Lógica server-side de garagens fixas e reservas
│   ├── sv-street-parking.lua# Validação de VIP, expiração (72h) e proteção offline
│   ├── sv-parking-meters.lua# Compra de tickets e fiscalização policial
│   └── sv-deformation.lua   # Armazenamento de deformação no banco
├── framework/
│   ├── cl-wrapper.lua       # Abstração client do QBox / QBCore / ESX
│   └── sv-wrapper.lua       # Abstração server do QBox / QBCore / ESX
├── locales/
│   └── pt-BR.lua            # Dicionário de tradução em Português
└── web/
    ├── index.html           # Interface NUI Lation Emerald
    ├── style.css            # Estilos CSS Lation Emerald Edition
    └── app.js               # Comunicação JS/NUI com FiveM
```

---

## 📄 Licença
Desenvolvido por **Haze Studios** © 2026. Todos os direitos reservados.
