local components = {}
local primaries = {}

-------------------------------------------------------------------------------

component = {}

function component.isAvailable(componentType)
  return primaries[componentType] ~= nil
end

function component.list(filter)
  local address, ctype = nil
  return function()
    repeat
      address, ctype = next(components, address)
    until not address or type(filter) ~= "string" or ctype:match(filter)
    return address, ctype
  end
end

function component.primary(componentType, ...)
  checkArg(1, componentType, "string")
  local args = table.pack(...)
  if args.n > 0 then
    checkArg(2, args[1], "string", "nil")
    local address
    if args[1] ~= nil then
      for c in component.list(componentType) do
        if c:usub(1, args[1]:ulen()) == args[1] then
          address = c
          break
        end
      end
      assert(address, "no such component")
    end
    local wasAvailable = component.isAvailable(componentType)
    primaries[componentType] = address
    if not wasAvailable and component.isAvailable(componentType) then
      event.fire("component_available", componentType)
    elseif wasAvailable and not component.isAvailable(componentType) then
      event.fire("component_unavailable", componentType)
    end
  else
    assert(component.isAvailable(componentType),
      "no primary '" .. componentType .. "' available")
    return primaries[componentType]
  end
end

function component.type(address)
  return components[address]
end

-------------------------------------------------------------------------------

local function onComponentAdded(_, address)
  if components[address] then
    return false -- cancel this event, it is invalid
  end
  local componentType = driver.componentType(address)
  components[address] = componentType
  if not component.isAvailable(componentType) then
    component.primary(componentType, address)
  end
end

local function onComponentRemoved(_, address)
  if not components[address] then
    return false -- cancel this event, it is invalid
  end
  local componentType = component.type(address)
  components[address] = nil
  if primaries[componentType] == address then
    component.primary(componentType, nil)
    address = component.list(componentType)()
    component.primary(componentType, address)
  end
end

function component.install()
  event.listen("component_added", onComponentAdded)
  event.listen("component_removed", onComponentRemoved)
end

function component.uninstall()
  event.ignore("component_added", onComponentAdded)
  event.ignore("component_removed", onComponentRemoved)
end
