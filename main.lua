-- ii.yazi: framed graphical preview adapter for Yazi.
-- Framed CLI output is committed on Yazi's main loop, never from a competing writer.

local M = {}

local emit = ya.mgr_emit or ya.emit or ya.manager_emit

local function current(url, skip)
  local tab = cx.active
  local hovered = tab.current.hovered
  if hovered and tostring(hovered.url) == url and tab.preview.skip == skip then
    return cx.tabs.idx
  end
end

local begin = ya.sync(function(state, url, skip)
  local tab = current(url, skip)
  if not tab then return end
  local seek = state.pending_seek
  if seek and (seek.tab ~= tab or seek.url ~= url) then
    state.pending_seek = nil
  end
  state.request = (state.request or 0) + 1
  return tab, state.request
end)

-- Commit graphics on Yazi's main loop, after rejecting superseded jobs. Writing
-- from the CLI races Yazi's own terminal writer during rapid navigation.
local publish_graphics = ya.sync(function(state, tab, request, url, skip, geometry, h, rows, packets)
  if state.request ~= request or current(url, skip) ~= tab then return false end
  local seek = state.pending_seek
  local scrolling = seek and seek.tab == tab and seek.url == url and seek.target == skip
  if scrolling then state.pending_seek = nil end
  if packets == false then state.page = nil; return true end
  local page = state.page
  local same = page and page.tab == tab and page.url == url and page.geometry == geometry
  if not packets then
    return true, same and math.min(skip - 1, page.last) or math.max(0, skip - h)
  end
  local reuse = scrolling and same and skip <= page.last and page.skip < skip + rows
  state.page = nil
  local sent, tty = {}, nil
  for _, upload in ipairs(packets) do
    local packet, key = upload[1], upload[2]
    if not (reuse and page.sent[key]) then
      tty = tty or io.open("/dev/tty", "wb") or io.stdout
      if not tty:write(packet) then
        if tty ~= io.stdout then tty:close() end
        return false
      end
    end
    sent[key] = true
  end
  if tty then
    local ok
    if tty == io.stdout then ok = tty:flush() else ok = tty:close() end
    if not ok then return false end
  end
  state.page = {
    url = url,
    tab = tab,
    skip = skip,
    last = skip + math.max(0, rows - 1),
    eof = rows < h,
    geometry = geometry,
    sent = sent,
  }
  return true
end)

-- Each replayable upload includes all continuations and its virtual placement.
-- Split and hash in the worker. Keep tmux DCS envelopes intact, and retain
-- only fingerprints of the uploads from the last successfully committed page.
local function uploads(apc)
  local prefix = apc:sub(1,2) == "\27P" and "\27Ptmux;\27\27_Ga=t," or "\27_Ga=t,"
  local parts, pos = {}, 1
  while pos <= #apc do
    local next_pos = apc:find(prefix, pos+1, true) or (#apc+1)
    local packet = apc:sub(pos, next_pos-1)
    parts[#parts+1] = { packet, ya.hash(packet) }
    pos = next_pos
  end
  return parts
end

local function path_of(job)
  return (tostring(job.file.path or job.file.url):gsub("^file://", ""))
end

function M:peek(job)
  local url, skip = tostring(job.file.url), job.skip
  local tab, request = begin(url, skip)
  if not tab then return end
  local path = path_of(job)
  local w = (job.area and job.area.w and job.area.w > 0) and job.area.w or 80
  local h = (job.area and job.area.h and job.area.h > 0) and job.area.h or 24

  local cw, ch
  if rt and rt.term and rt.term.cell_size then
    cw, ch = rt.term.cell_size()
  end
  local cell_size_arg = (cw and ch and cw >= 1 and ch >= 1)
    and string.format("%dx%d", math.floor(cw), math.floor(ch))
  local is_light = (rt and rt.term and rt.term.light and rt.term.light()) or false
  local theme_arg = is_light and "light" or "dark"
  local geometry = table.concat({w, h, cell_size_arg or "default", theme_arg}, "/")
  local function fail(message)
    if publish_graphics(tab, request, url, skip, geometry, h, 0, false) then
      ya.preview_widget(job, ui.Text("ii: " .. message):area(job.area))
    end
  end

  local command = Command("ii")
    :arg("--machine")
    :arg("--size")
    :arg(string.format("%dx%d", w, h))
  if cell_size_arg then command:arg("--cell-size"):arg(cell_size_arg) end
  local child, spawn_error = command
    :arg("--skip")
    :arg(tostring(skip))
    :arg("--theme")
    :arg(theme_arg)
    :arg("--")
    :arg(path)
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :output()

  if not child or not child.status.success then
    fail(child and child.stderr or tostring(spawn_error or "failed to start"))
    return
  end

  local raw = child.stdout
  if #raw < 4 then fail("incomplete preview frame"); return end
  local a,b,c,d = raw:byte(1,4)
  local n = a+b*256+c*65536+d*16777216
  if n > #raw-4 then fail("invalid preview frame"); return end
  local text = raw:sub(5+n)
  if text == "" and skip > 0 then
    local accepted, upper = publish_graphics(tab, request, url, skip, geometry, h)
    if accepted then
      emit("peek", { upper, only_if = job.file.url, upper_bound = true })
    end
    return
  end
  local rows = 0
  for _ in text:gmatch("\n") do rows = rows + 1 end
  if text ~= "" and text:sub(-1) ~= "\n" and text:sub(-5) ~= "\n\27[0m" then
    rows = rows + 1
  end
  if not publish_graphics(tab, request, url, skip, geometry, h, rows, uploads(raw:sub(5,4+n))) then return end
  ya.preview_widget(job, ui.Text.parse(text):area(job.area))
end

function M:seek(job)
  local active = cx.active
  local hovered = active.current.hovered
  if not hovered or hovered.url ~= job.file.url then return end
  local tab, url = cx.tabs.idx, tostring(job.file.url)
  local skip = tonumber(active.preview.skip) or 0
  local pending = self.pending_seek
  local base = pending and pending.tab == tab and pending.url == url and pending.target or skip
  local target = math.max(0, base + (tonumber(job.units) or 0))
  local page = self.page
  if page and page.tab == tab and page.url == url and page.skip == skip and page.eof then
    target = math.min(target, page.last)
  end
  if target == base then return end
  self.pending_seek = { tab = tab, url = url, target = target }
  emit("peek", { target, only_if = job.file.url })
end

function M:preload(_) return true end

return M
