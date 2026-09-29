# 🧪 Guia Completo de Testes — haze_garages



Este documento apresenta o protocolo oficial de testes e validação de qualidade (QA) para o recurso **`haze_garages`**.

---

## 📋 Pré-requisitos & Checklist de Instalação

Antes de iniciar os testes, certifique-se de que os seguintes pontos foram cumpridos:

- [x] O resource `haze_garages` está em `resources/[ai_create]/haze_garages`.
- [x] O arquivo `server.cfg` contém `ensure haze_garages` e os recursos legados (`jg-advancedgarages`, `qb-parking-main`, `vrs_garage-main`, `Fivem-Vehicle-Persistence-main`, `mo_parkingMeter`) foram parados (`stop`).
- [x] O item `parking_ticket` está registrado no `ox_inventory/data/items.lua`.
- [x] O MySQL (`oxmysql`) está rodando normalmente.

---

## 🧪 Roteiro de Testes por Módulo

### Módulo 1: Boot Automático & Banco de Dados (SQL Check)

**Objetivo:** Confirmar a criação automática das tabelas e inicialização limpa sem erros no console.

1. Inicie ou reinicie o servidor / resource:
   ```cmd
   restart haze_garages
   ```
2. Observe os logs do console do servidor:
   - **Resultado Esperado:** Mensagem `[HazeGarages] Tabelas de banco de dados verificadas/criadas com sucesso.`
3. Verifique seu gerenciador SQL (HeidiSQL / phpMyAdmin):
   - Confirme se as seguintes tabelas foram criadas automaticamente:
     - `haze_street_parking`
     - `haze_fixed_garages`
     - `haze_parking_meters`
     - `haze_vehicle_deformations`

---

### Módulo 2: Garagens Fixas (Públicas, Job e Gangue)

**Objetivo:** Testar NUI Lation Emerald, retendo/guardando veículos e controle de permissões.

| Passo | Ação | Resultado Esperado |
| :--- | :--- | :--- |
| **2.1** | Vá até a Garagem Central da Legion Square (`coords: 215.12, -810.55, 30.7`). | O prop `prop_parkstat_01` estará visível no local. |
| **2.2** | Mire no terminal com `ox_target` ou pressione **E**. | Abre a NUI Lation Emerald listando os veículos do jogador. |
| **2.3** | Observe o painel do veículo selecionado na NUI. | Exibe informações de combustível, vida do motor/lataria e barras de desgaste de peças (`granolla_mechanic`). |
| **2.4** | Clique em **"Retirar Veículo"**. | O veículo spawna na vaga designada. A chave é concedida via `qbx_vehiclekeys`. |
| **2.5** | Guarde o veículo no marcador da garagem. | O veículo é removido do mapa, a chave é revogada e o status `state` no banco passa para `1` (Guardado). |
| **2.6** | Tente abrir a garagem da Polícia (`police_main`) sem o job `police`. | O acesso é recusado com notificação de permissão negada. |

---

### Módulo 3: Estacionamento Persistente de Rua (`/estacionar`)

**Objetivo:** Testar cobrança de taxa, gratuidade no mesmo local, limites VIP, proteção offline e expiração (72h).

| Passo | Ação | Resultado Esperado |
| :--- | :--- | :--- |
| **3.1** | Entre em um veículo próprio e execute `/estacionar` em uma rua. | Cobra a taxa inicial ($250) e salva as coordenadas do local. |
| **3.2** | Entre no veículo e execute `/estacionar` no **mesmo local** (tolerância de 10m). | **Gratuito!** Não cobra taxa adicional. |
| **3.3** | Dirija para um local distante (> 10m) e execute `/estacionar`. | Remove a vaga antiga, cobra a taxa de $250 e salva a nova vaga de rua. |
| **3.4** | Tente estacionar mais veículos do que o limite do seu grupo (ex: 2º carro sem VIP). | Bloqueia o estacionamento informando que o limite de vagas VIP foi atingido. |
| **3.5 (Proteção Offline)** | Estacione o carro na rua. Desconecte o jogador proprietário. Outro jogador tenta usar lockpick/hotwire no carro. | **Bloqueado!** Notificação informa que o dono está offline e que o veículo só aceita a chave original. |
| **3.6 (Expiração 72h)** | Altere manualmente a coluna `updated_at` na tabela `haze_street_parking` para 4 dias atrás e reinicie o script. | O veículo da rua expira e é enviado automaticamente para a garagem fixa mais próxima (`legion_square`). |

---

### Módulo 4: Parquímetros Interativos & Fiscalização Policial

**Objetivo:** Validar compra de tickets, geração do item no inventário e sistema de multas policiais.

1. **Pagamento do Parquímetro:**
   - Aproxime-se de um parquímetro nativo (`prop_parkstat_01`, etc.) ou customizado.
   - Mire com o `ox_target` e selecione **"Pagar Parquímetro"**.
   - Escolha pagar por 1 hora ($50).
   - **Resultado Esperado:** O valor é descontado e um item `parking_ticket` é adicionado ao seu `ox_inventory` com a metadata contendo a placa do veículo mais próximo e horário de validade.

2. **Fiscalização Policial (`police` / `sheriff`):**
   - Mude para um personagem com a profissão `police` ou `sheriff`.
   - Mire em um veículo estacionado na rua e escolha **"Fiscalizar Parquímetro"**.
   - **Cenário A (Veículo Regularizado):** Se o ticket estiver no inventário ou no sistema com horário válido, exibe mensagem: *"Parquímetro regularizado até HH:MM"*.
   - **Cenário B (Sem Ticket ou Vencido):** Exibe notificação de infração e aplica uma multa bancária automática de $500 ao proprietário do veículo.

---

### Módulo 5: Desgaste Mecânico (`granolla_mechanic`) & Deformação

**Objetivo:** Garantir a integração fluida de dados de mecânica e deformação física.

1. Provoque danos no motor, lataria e pneus do veículo.
2. Guarde o veículo na garagem fixa ou use `/estacionar`.
3. Abra a NUI da garagem ou retire o veículo:
   - **Resultado Esperado:** As barras de progresso na NUI refletem exatamente os percentuais de dano do `granolla_mechanic`.
   - Ao retirar o veículo, a lataria deforma e mantém os amassados exatamente como quando foi guardado.

---

### Módulo 6: Teste de Desempenho & Resmon

1. Abra o console F8 no client e digite `resmon`.
2. Procure por `haze_garages`:
   - **Em Repouso:** Consumo de CPU entre `0.00ms` e `0.01ms`.
   - **Ao Estacionar/Abrir NUI:** Pico temporário $\le 0.03\text{ms}$.
3. Afaste-se 70 metros de um veículo estacionado na rua:
   - Confirmar no `resmon` que o streaming por `ox_lib.points` descarregou o veículo da memória gráfica sem vazamentos.

---

## 🛠️ Resolução de Problemas (Troubleshooting)

- **Problema:** O item `parking_ticket` não aparece no inventário.
  - *Solução:* Certifique-se de que adicionou a entrada de `parking_ticket` em `ox_inventory/data/items.lua` e reiniciou o inventário.
- **Problema:** NUI não abre ao interagir com o terminal.
  - *Solução:* Verifique se o `ox_target` está iniciado e se não há erros JS no F12 (NUI DevTools).
- **Problema:** O veículo não é retido ao deslogar.
  - *Solução:* Verifique se o `Config.StreetParkingExpirationHours` está configurado corretamente e se as tabelas MySQL possuem a chave primária `plate`.

---
Desenvolvido por **Haze Studios** © 2026.
