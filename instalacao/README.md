# 📦 Instalação & Guia — haze_garages (Haze Studios)

Sistema enterprise de **Garagens Fixas, Estacionamento Persistente de Rua (`/estacionar`), Parquímetros Interativos, Fiscalização Policial e Deformação Persistente** para **Qbox, QBCore e ESX**.

---

## 📋 Requisitos e Dependências

| Resource | Versão | Função |
|---|---|---|
| `qbx_core`, `qb-core` ou `esx` | Mais recente | Framework base (Suporte multi-framework automático) |
| `ox_lib` | ≥ 3.32.2 | Callbacks, Points spatial grid, TextUI, NUI e notificações |
| `ox_target` | ≥ 1.18.1 | Interação em parquímetros, garagens e veículos |
| `ox_inventory` | ≥ 2.47.9 | Item de ticket de parquímetro (`parking_ticket`) com metadata |
| `oxmysql` | ≥ 2.14.1 | Banco de dados MySQL |
| `granolla_mechanic` | Opcional | Leitura em tempo real do desgaste de peças do veículo |

---

## ⚙️ Passo a Passo de Instalação

### 1. Banco de Dados
O `haze_garages` cria automaticamente todas as tabelas necessárias (`haze_street_parking`, `haze_fixed_garages`, `haze_parking_meters`, `haze_vehicle_deformations`) no evento `MySQL.ready`. **Não é necessário importar arquivos SQL manualmente.**

### 2. Item no `ox_inventory`
Adicione o item `parking_ticket` no seu arquivo `ox_inventory/data/items.lua`:

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

### 3. `server.cfg`
Certifique-se de iniciar os recursos na ordem correta:

```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure oxmysql
ensure qbx_vehiclekeys # ou qb-vehiclekeys
ensure granolla_mechanic # se utilizado
ensure haze_garages
```

---

## ⚙️ Opções Principais do `config.lua`

| Chave | Padrão | Descrição |
|---|---|---|
| `Config.Framework` | `"auto"` | Detecta automaticamente `qbx_core`, `qb-core` ou `ESX` |
| `Config.StreetParkCommand` | `"estacionar"` | Comando para estacionar ou guardar veículos na rua |
| `Config.StreetParkingFee` | `250` | Custo na primeira vez em que um novo ponto de rua é registrado |
| `Config.DynamicSpotTolerance` | `10.0` | Distância (em metros) para considerar o mesmo ponto salvo gratuito |
| `Config.StreetParkingExpirationHours` | `72` | Horas de inatividade para expirar vaga de rua e enviar o carro à garagem mais próxima |
| `Config.ParkingMeterPricePerHour` | `50` | Custo por hora nos parquímetros |
| `Config.PoliceFineAmount` | `500` | Valor da multa bancária emitida pela polícia por parquímetro vencido |
| `Config.FixedGarages` | Tabela | Garagens fixas (Públicas, Corporativas/Job e Gangues) |

---

## 📲 Comandos & Atalhos

- `/estacionar`: Estacionar ou recolher o veículo atual na vaga de rua mais próxima / coordenada atual.
- `ox_target` &rarr; **Terminal da Garagem**: Abre a interface NUI Lation Emerald para retirar ou visualizar veículos salvos.
- `ox_target` &rarr; **Pagar Parquímetro**: Paga o tempo de permanência e emite o item `parking_ticket`.
- `ox_target` &rarr; **Fiscalizar Parquímetro** (Exclusivo Polícia): Verifica o tempo restante do veículo ou aplica multa por infração.
