-- Small helpers shared by the other files (global `o`, kept from the Omarchy days).

o = {}

function o.sh(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- Launch through uwsm so apps get their own systemd scope.
function o.launch(command)
  return "uwsm-app -- " .. command
end

function o.noctalia(args)
  return "noctalia msg " .. args
end

-- Webapps run in the Mateo Chrome profile ("Profile 1").
function o.webapp(url)
  return o.launch("google-chrome-stable --app=" .. o.sh(url) .. " --profile-directory='Profile 1'")
end

-- Focus the first window whose class or title contains `needle`, else run `command`.
function o.launch_or_focus(needle, command)
  return function()
    local lower = needle:lower()
    for _, window in ipairs(hl.get_windows() or {}) do
      local class = (window.class or ""):lower()
      local title = (window.title or ""):lower()
      if class:find(lower, 1, true) or title:find(lower, 1, true) then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
        return
      end
    end
    hl.exec_cmd(command)
  end
end

function o.bind(keys, description, dispatcher, options)
  local opts = options or {}
  opts.description = description
  if type(dispatcher) == "string" then
    dispatcher = hl.dsp.exec_cmd(dispatcher)
  end
  hl.bind(keys, dispatcher, opts)
end

function o.rebind(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

function o.window(match, rules)
  rules.match = rules.match or {}
  if type(match) == "string" then
    rules.match.class = match
  else
    for key, value in pairs(match) do
      rules.match[key] = value
    end
  end
  hl.window_rule(rules)
end
