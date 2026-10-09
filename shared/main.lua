Haze = Haze or {}
Haze.Shared = Haze.Shared or {}

local localeName = Config.Locale or "pt-BR"
Locale = Locales[localeName] or Locales['pt-BR']

function Haze.Shared.CleanPlate(plate)
    if not plate or type(plate) ~= "string" then return "" end
    return string.upper(string.gsub(plate, "^%s*(.-)%s*$", "%1"))
end

function Haze.Shared.GetDistance(coords1, coords2)
    local v1 = vec3(coords1.x, coords1.y, coords1.z)
    local v2 = vec3(coords2.x, coords2.y, coords2.z)
    return #(v1 - v2)
end

function Haze.Shared.FormatMoney(amount)
    return string.format("%s%s", Config.Currency or "$", amount)
end

function Haze.Shared.GetModelHash(model)
    if not model then return nil end
    if type(model) == "number" then return math.floor(model) end
    local num = tonumber(model)
    if num then return math.floor(num) end
    return joaat(tostring(model))
end

function Haze.Shared.FindNearestFixedGarage(coords)
    local nearestId = "legion_square"
    local minDistance = 999999.0

    if not coords then return nearestId end
    local cX = coords.x or (coords[1] or 0)
    local cY = coords.y or (coords[2] or 0)
    local cZ = coords.z or (coords[3] or 0)
    local vecCoords = vec3(cX, cY, cZ)

    for garageId, gData in pairs(Config.FixedGarages or {}) do
        if gData.category == "car" or not gData.category then
            local gCoords = vec3(gData.coords.x, gData.coords.y, gData.coords.z)
            local dist = #(vecCoords - gCoords)
            if dist < minDistance then
                minDistance = dist
                nearestId = garageId
            end
        end
    end
    return nearestId
end


