local DEBUG_MODE = true
local function debug(text)
	if text == nil then
		text = "NIL"
	end
	if DEBUG_MODE then
		local time = os.date("%X")
		local prompt = "T:" .. tostring(time) .. "// ERR: " .. text
		gma.echo(prompt)
		gma.feedback(prompt)
	end
end

local function err_error_handler(err)
	local error_msg = "Error processing fixture layer:\n" .. tostring(err)

	local continue = gma.gui.confirm(
		"Error Processing Layer",
		error_msg .. "\n\nPress [OK] to continue with remaining layers\nPress [CANCEL] to terminate plugin"

	)

	if continue then
		debug("User chose to continue after error: " .. error_msg)
		-- error("Plugin terminated by user")
		return "CONTINUE"
	else
		debug("User chose to terminate after error: " .. error_msg)
		error("Plugin terminated by user")
	end
end


local function deep_copy(orig)
	local orig_type = type(orig)
	local copy

	if orig_type == "table" then
		copy = {}                                   
		for orig_key, orig_value in next, orig, nil do
			copy[deep_copy(orig_key)] = deep_copy(orig_value) 
		end
		setmetatable(copy, deep_copy(getmetatable(orig))) 
	else
		copy =
			orig 
	end

	return copy
end


function CLONE()
end

return CLONE
