# 🚗 haze_garages — Haze Studios

Sistema unificado de Garagens, Estacionamento Persistente de Rua (`/estacionar`) e Parquímetros Interativos.

---

## 🛠️ Stack e Compatibilidade
- **Core / Framework:** `qbx_core` (1.23.0), `QBCore`, `ESX` (Detecção Automática)
- **UI / Interactions:** `ox_lib` (3.32.2), `ox_target`
- **Database:** `oxmysql`
- **Design System NUI:** Lation Modern UI — Emerald Edition (`#10b981` / `#6afe87` / `#1e1f24`)

---

## ✨ Funcionalidades Principais

### 1. Estacionamento de Rua Persistente (`/estacionar`)
- Permite estacionar o veículo em qualquer lugar da rua.
- **Primeiro estacionamento em novo local dinâmico:** Cobra a taxa configurada (`Config.StreetParkingFee = 250`) e registra aquele ponto no banco de dados para o veículo.
- **Próximas vezes no MESMO local:** Gratuito!
- **Mudar para um NOVO local de rua:** Substitui o ponto salvo antigo, cobra a taxa novamente e registra a nova posição.
- **Sem Broadcasts Globais:** Utliza o Spatial Grid (`ox_lib` points) para streaming de veículos por proximidade.

### 2. Garagens Fixas com Terminais (Sem Peds)
- Suporte para garagens fixas públicas e privadas no mapa.
- Substituição de peds por props elegantes (`prop_parkstat_01`).
- Sistema de reservas de spawn (`spawnReservations`) para prevenir duplicatas de veículos por lag/clique duplo.

### 3. Parquímetros Interativos Pagos por Hora
- Suporte a modelos de parquímetros nativos do GTA V (`prop_parkstat_01`, `prop_parkstat_02`, `prop_parkstat_03`, `prop_parkingpay_01`).
- Coordenadas de parquímetros customizados totalmente configuráveis em `config.lua`.
- Pagamento por hora (1h ou 10h) com revalidação estrita server-side.

### 4. Persistência de Deformação e Danos
- Salva o estado de danos mecânicos (motor, lataria, tanque) e a deformação física dos vértices da carcaça do veículo.

### 5. Criação Automática do Banco de Dados
- Executa `CREATE TABLE IF NOT EXISTS` no evento `MySQL.ready` para criar as tabelas `haze_street_parking`, `haze_fixed_garages`, `haze_parking_meters` e `haze_vehicle_deformations` automaticamente no boot.

---

## 💻 Comandos e Atalhos
- `/estacionar`: Estacionar ou recolher o veículo no local atual de rua.

---

## 📄 Licença
Desenvolvido por **Haze Studios** © 2026. Todos os direitos reservados.
