-- ============================================================
--  Song Navigator | Navegador de Secciones
--  Sistema de loops en vivo para servicios de iglesia
--
--  TECLAS:
--   ↑↓       Mover cursor (para salto manual con Enter)
--   Enter    Saltar ahora a la sección del cursor (limpia cola)
--   Space    Play / Stop
--   1-9      Agregar sección a la cola
--   R        Recargar regiones
--   Esc      Cerrar
-- ============================================================

local FONT           = "Arial"
local FONT_SZ        = 16
local ROW_H          = 40
local HEADER_H       = 70
local FOOTER_H       = 95
local WIN_W          = 420
local JUMP_THRESHOLD = 0.10   -- seg antes del fin para disparar el salto
local JUMP_COOLDOWN  = 0.28   -- evita doble salto

local regions     = {}
local next_idx    = 1
local last_jump   = -999
local queue       = {}
local WIN_H       = 400

-- ================================================================

local function collect_regions()
  regions = {}
  local i = 0
  while true do
    local ok, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers(i)
    if ok == 0 then break end
    if isrgn then
      table.insert(regions, { name = name, s = pos, e = rgnend })
    end
    i = i + 1
  end
  table.sort(regions, function(a, b) return a.s < b.s end)
  WIN_H = math.max(280, math.min(HEADER_H + #regions * ROW_H + FOOTER_H, 860))
end

local function is_playing()
  return (reaper.GetPlayState() & 1) == 1
end

local function region_at(pos)
  for i, r in ipairs(regions) do
    if pos >= r.s and pos < r.e then return i end
  end
end

local function jump_to(idx)
  next_idx  = idx
  last_jump = reaper.time_precise()
  reaper.SetEditCurPos(regions[idx].s, true, true)
  if not is_playing() then reaper.OnPlayButton() end
end

-- ================================================================

local function handle_playback()
  if not is_playing() then return end
  if reaper.time_precise() - last_jump < JUMP_COOLDOWN then return end

  local pos    = reaper.GetPlayPosition()
  local active = region_at(pos)

  if active then
    if regions[active].e - pos <= JUMP_THRESHOLD then
      local dest = #queue > 0 and table.remove(queue, 1) or (active % #regions) + 1
      jump_to(dest)
    end
  else
    local dest = #queue > 0 and table.remove(queue, 1) or next_idx
    jump_to(dest)
  end
end

-- ================================================================

local function sg(r, g, b, a)
  gfx.r, gfx.g, gfx.b, gfx.a = r, g, b, a or 1.0
end

local function queue_pos_of(idx)
  for qi, qidx in ipairs(queue) do
    if qidx == idx then return qi end
  end
end

local function draw()
  sg(0.07, 0.07, 0.11); gfx.rect(0, 0, WIN_W, WIN_H, true)

  local pos        = reaper.GetPlayPosition()
  local playing    = is_playing()
  local active_idx = region_at(pos)
  local eff_next   = #queue > 0 and queue[1] or next_idx

  -- Header
  gfx.setfont(1, FONT, 19, 98); sg(0.88, 0.88, 1.0)
  gfx.x, gfx.y = 14, 8; gfx.drawstr("Song Navigator")

  gfx.setfont(1, FONT, 13)
  if playing then
    sg(0.2, 0.85, 0.4);   gfx.x, gfx.y = 14, 36; gfx.drawstr("\xE2\x97\x8F REPRODUCIENDO")
  else
    sg(0.85, 0.75, 0.15); gfx.x, gfx.y = 14, 36; gfx.drawstr("\xE2\x96\xA0 DETENIDO")
  end
  if active_idx then
    sg(0.45, 0.55, 0.75); gfx.x, gfx.y = 180, 36
    gfx.drawstr("en: " .. regions[active_idx].name)
  end

  sg(0.18, 0.18, 0.28); gfx.line(0, HEADER_H - 1, WIN_W, HEADER_H - 1)

  -- Lista de regiones
  for i, r in ipairs(regions) do
    local y      = HEADER_H + (i - 1) * ROW_H
    local is_act = (i == active_idx)
    local is_nxt = (i == eff_next)
    local qpos   = queue_pos_of(i)

    -- Fondo + barra lateral
    if is_act then
      sg(0.14, 0.32, 0.62, 0.45); gfx.rect(0, y, WIN_W, ROW_H, true)
      sg(0.30, 0.60, 1.0);        gfx.rect(0, y, 4, ROW_H, true)
    elseif is_nxt then
      sg(0.50, 0.30, 0.04, 0.35); gfx.rect(0, y, WIN_W, ROW_H, true)
      sg(1.0,  0.62, 0.08);       gfx.rect(0, y, 4, ROW_H, true)
    elseif qpos then
      sg(0.40, 0.22, 0.03, 0.20); gfx.rect(0, y, WIN_W, ROW_H, true)
      sg(0.80, 0.45, 0.05);       gfx.rect(0, y, 4, ROW_H, true)
    end

    -- Barra de progreso
    if is_act and playing then
      local dur = r.e - r.s
      if dur > 0 then
        sg(0.28, 0.56, 1.0, 0.30)
        gfx.rect(4, y + ROW_H - 5, (WIN_W - 4) * math.max(0, math.min(1, (pos - r.s) / dur)), 5, true)
      end
    end

    -- Nombre
    gfx.setfont(1, FONT, FONT_SZ, is_act and 98 or 0)
    if is_act then      sg(0.45, 0.78, 1.0)
    elseif is_nxt then  sg(1.0,  0.75, 0.22)
    elseif qpos then    sg(0.90, 0.58, 0.15)
    else                sg(0.58, 0.58, 0.70) end

    gfx.x, gfx.y = 16, y + (ROW_H - FONT_SZ) / 2
    gfx.drawstr((is_act and "\xE2\x96\xB6 " or is_nxt and "\xE2\x86\x92 " or "   ") .. r.name)

    -- Badge derecho
    gfx.setfont(1, FONT, 11)
    if qpos or i <= 9 then
      if qpos then sg(1.0, 0.62, 0.08) else sg(0.28, 0.28, 0.40) end
      gfx.x, gfx.y = WIN_W - 18, y + (ROW_H - 11) / 2
      gfx.drawstr(tostring(qpos or i))
    end

    sg(0.12, 0.12, 0.19); gfx.line(4, y + ROW_H - 1, WIN_W - 4, y + ROW_H - 1)
  end

  -- Footer
  local fy = HEADER_H + #regions * ROW_H
  sg(0.18, 0.18, 0.28); gfx.line(0, fy, WIN_W, fy)
  gfx.setfont(1, FONT, 12); sg(0.32, 0.32, 0.44)
  gfx.x, gfx.y = 10, fy + 7;  gfx.drawstr("\xE2\x86\x91\xE2\x86\x93 Cursor   Enter Saltar ya   Space Play/Stop")
  gfx.x, gfx.y = 10, fy + 25; gfx.drawstr("1-9 Encolar   R Recargar   Esc Cerrar")

  if #queue > 0 then
    local names = {}
    for _, qi in ipairs(queue) do table.insert(names, regions[qi] and regions[qi].name or "?") end
    local total = #names
    while #names > 1 and gfx.measurestr("COLA: " .. table.concat(names, " \xE2\x86\x92 ") .. " \xE2\x86\x92 ...") > WIN_W - 20 do
      table.remove(names)
    end
    sg(1.0, 0.62, 0.08); gfx.x, gfx.y = 10, fy + 50
    gfx.drawstr("COLA: " .. table.concat(names, " \xE2\x86\x92 ") .. (#names < total and " \xE2\x86\x92 ..." or ""))
  elseif active_idx and eff_next ~= active_idx then
    sg(0.35, 0.35, 0.50); gfx.x, gfx.y = 10, fy + 50
    gfx.drawstr("SIGUIENTE \xE2\x86\x92  " .. regions[eff_next].name .. "  (cronológico)")
  end

  gfx.update()
end

-- ================================================================

local function handle_input()
  local char = gfx.getchar()
  if char == -1 then return false end
  if char == 0  then return true  end

  if char == 30064 then
    next_idx = math.max(1, next_idx - 1)
  elseif char == 30065 then
    next_idx = math.min(#regions, next_idx + 1)
  elseif char == 13 then
    queue = {}
    jump_to(next_idx)
  elseif char == 32 then
    if is_playing() then reaper.OnStopButton() else reaper.OnPlayButton() end
  elseif char >= 49 and char <= 57 then
    local idx = char - 48
    if regions[idx] then table.insert(queue, idx) end
  elseif (char | 32) == 114 then
    collect_regions()
    next_idx = math.min(next_idx, #regions)
    queue = {}
  elseif char == 27 then
    return false
  end

  return true
end

-- ================================================================

local function main()
  if not handle_input() then gfx.quit(); return end
  handle_playback()
  draw()
  reaper.defer(main)
end

-- ================================================================

collect_regions()

if #regions == 0 then
  reaper.ShowMessageBox(
    "No se encontraron regiones en el proyecto.\n\nCrea regiones en Reaper para definir las secciones:\nIntro, Estrofa, Pre-coro, Coro, Puente, Outro, etc.\n\nMenú: Insert > Region from time selection",
    "Song Navigator", 0)
  return
end

gfx.init("Song Navigator", WIN_W, WIN_H, 0, 80, 80)
reaper.defer(main)
