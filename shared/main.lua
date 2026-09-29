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
    return string.format("%s%s", Config.Currency or "R$", amount)
end

function Haze.Shared.GetModelHash(model)
    if not model then return nil end
    local num = tonumber(model)
    if num then
        return math.floor(num)
    end
    return joaat(tostring(model))
end

