Locales = Locales or {}

Locales['pt-BR'] = {
    -- Geral
    system_name = "Haze Garages",
    not_in_vehicle = "Você precisa estar dentro de um veículo.",
    not_vehicle_owner = "Você não possui os documentos deste veículo.",
    no_money = "Você não possui dinheiro suficiente (%s%s).",
    
    -- Estacionamento de Rua (/estacionar)
    street_parked_new_spot = "Veículo estacionado no novo ponto de rua! Taxa de %s%s paga. Nas próximas vezes neste local será gratuito.",
    street_parked_free_spot = "Veículo estacionado na sua vaga de rua registrada (Gratuito).",
    street_parked_replaced = "Você alterou sua vaga de rua para este novo local. Taxa de %s%s cobrada.",
    street_park_removed = "Veículo retirado da vaga de rua.",

    -- Garagens Fixas
    garage_open_prompt = "Pressione ~g~[E]~s~ para acessar a garagem",
    garage_store_prompt = "Pressione ~g~[E]~s~ para guardar o veículo",
    vehicle_stored = "Veículo guardado na garagem com sucesso.",
    vehicle_spawned = "Veículo retirado da garagem com sucesso.",
    spawn_blocked = "O local de saída do veículo está bloqueado!",

    -- Parquímetros
    meter_prompt = "Parquímetro | R$ %s/Hora | Pressione [E] 1h ou [X] 10h",
    meter_paid = "Pagamento de %s horas efetuado com sucesso (%s%s).",
    meter_expired = "O tempo do parquímetro para esta vaga expirou!",

    -- Validações e Erros
    vehicle_already_outside = "Este veículo já está fora da garagem!",
    error_spawn_reservation = "Aguarde um momento antes de solicitar o veículo novamente."
}
