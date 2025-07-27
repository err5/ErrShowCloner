local VERSION = "v0.4.0"
local DEBUG_MODE = true

-- Outputs debug messages to console and feedback
--@param text The text to display
--@return nil
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

local name = 'username'

-- Handles errors with user prompt to continue or terminate
--@param err The error message
--@return "CONTINUE" if user chooses to continue, or terminates execution
local function err_error_handler(err)
	local error_msg = tostring(err)

	local ok = gma.gui.confirm(
		"Error",
		error_msg .. "\n\nPress [OK] to continue\nPress [CANCEL] to terminate plugin"
	)

	if ok then
		debug("User chose to continue after error: " .. error_msg)
		return
	else
		debug("User chose to terminate after error: " .. error_msg)
		error("Plugin terminated by user")
	end
end

-- Returns the current show path
--@return string The full path to the show directory
local PATH = function()
	return gma.show.getvar('PATH')
end

-- Creates a deep copy of a table or value
--@param orig The original value to copy
--@return A deep copy of the original value
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
		copy = orig
	end

	return copy
end

---@class FX
---@field data table Contains effects data
local FX = {}
FX.__index = FX

-- FX class constructor
---@return FX A new FX object instance
function FX.new()
	local self = setmetatable({}, FX)
	self.data = {
		effects = {}
	}
	return self
end

-- Parses all effects from the effect pool XML
--@param fx_range The range of effects to parse in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@return FX self The FX object for method chaining, or error handler result
function FX:parse(fx_range)
	if not fx_range then
		return err_error_handler("No range provided for effect parsing")
	end

	gma.cmd('Export Effect ' .. fx_range .. ' "effect_pool.xml" /o /nc')

	local file_path = PATH() .. "/effects/effect_pool.xml"
	local file = io.open(file_path, "r")
	if not file then
		return err_error_handler("Could not open file: " .. file_path)
	end

	local content = file:read("*all")
	file:close()

	if not content or content == "" then
		return err_error_handler("Effect pool file is empty or corrupted")
	end

	for effect_tag in content:gmatch("<Effect.-</Effect>") do
		local effect_index = effect_tag:match('index="(%d+)"')
		if effect_index then
			local effect_data = {
				index = tonumber(effect_index),
				forms = {},
				effectlines = {},
				effectdata = {}
			}

			for form in effect_tag:gmatch("<Form.-</Form>") do
				local form_data = {
					index = tonumber(form:match('index="(%d+)"')),
					name = form:match('name="([^"]+)"'),
					display_2d = form:match('display_2d="([^"]+)"') == "true",
					subforms = {}
				}

				for subform in form:gmatch("<SubForm.-</SubForm>") do
					local subform_data = {
						index = tonumber(subform:match('index="(%d+)"')),
						display_spec_index = tonumber(subform:match('display_spec_index="(%d+)"')),
						graph_color = subform:match('graph_color="([^"]+)"'),
						points = {}
					}

					for point in subform:gmatch("<SubFormPoint.-/>") do
						local point_data = {
							index = tonumber(point:match('index="(%d+)"')),
							x = tonumber(point:match('x="([^"]+)"')),
							y = tonumber(point:match('y="([^"]+)"')),
							mode = point:match('mode="([^"]+)"')
						}
						table.insert(subform_data.points, point_data)
					end

					table.insert(form_data.subforms, subform_data)
				end

				table.insert(effect_data.forms, form_data)
			end

			for effectline in effect_tag:gmatch("<Effectline.-</Effectline>") do
				local effectline_data = {
					index = tonumber(effectline:match('index="(%d+)"')),
					attribute = effectline:match('attribute="([^"]+)"'),
					blocks = tonumber(effectline:match('blocks="(%d+)"')),
					groups = tonumber(effectline:match('groups="(%d+)"')),
					wings = tonumber(effectline:match('wings="(%d+)"')),
					rate = tonumber(effectline:match('rate="([^"]+)"')),
					v1_a = tonumber(effectline:match('v1_a="([^"]+)"')),
					v1_b = tonumber(effectline:match('v1_b="([^"]+)"')),
					v2_a = tonumber(effectline:match('v2_a="([^"]+)"')),
					v2_b = tonumber(effectline:match('v2_b="([^"]+)"')),
					phase_a = tonumber(effectline:match('phase_a="([^"]+)"')),
					phase_b = tonumber(effectline:match('phase_b="([^"]+)"')),
					width_a = tonumber(effectline:match('width_a="([^"]+)"')),
					width_b = tonumber(effectline:match('width_b="([^"]+)"')),
					pwm_attack = tonumber(effectline:match('pwm_attack="([^"]+)"')),
					pwm_decay = tonumber(effectline:match('pwm_decay="([^"]+)"')),
					interleave = tonumber(effectline:match('interleave="(%d+)"')),
					flags = {
						absolute_mode = effectline:match('absolute_mode="([^"]+)"') == "true",
						form_index = tonumber(effectline:match('form_index="(%d+)"')),
						sub_form_index = tonumber(effectline:match('sub_form_index="(%d+)"')),
						pwm_type = effectline:match('pwm_type="([^"]+)"'),
						attack = tonumber(effectline:match('attack="(%d+)"')),
						decay = tonumber(effectline:match('decay="(%d+)"')),
						reverse = effectline:match('reverse="([^"]+)"') == "true",
						bounce = effectline:match('bounce="([^"]+)"') == "true",
						speed_master = tonumber(effectline:match('speed_master="(%d+)"'))
					},
					fixtures = {}
				}

				for fixture in effectline:gmatch("<Fixture>([^<]+)</Fixture>") do
					table.insert(effectline_data.fixtures, fixture)
				end

				table.insert(effect_data.effectlines, effectline_data)
			end

			for effectdata in effect_tag:gmatch("<EFFECTDATA.-/>") do
				local effectdata_data = {
					line = tonumber(effectdata:match('line="(%d+)"')),
					fixture = effectdata:match('fixture="([^"]+)"'),
					phase = tonumber(effectdata:match('phase="(%d+)"'))
				}
				table.insert(effect_data.effectdata, effectdata_data)
			end

			table.insert(self.data.effects, effect_data)
		else
			debug("Warning: Effect tag without index found, skipping")
		end
	end

	return self
end

-- Creates a new effect with the given parameters
--@param params Table of effect parameters including form, subform, points, and effectlines
--@return FX self The FX object for method chaining, or error handler result
function FX:create(params)
	if not params then
		return err_error_handler("No parameters provided for effect creation")
	end

	self.data = {
		effects = {}
	}

	if not params.form then
		return err_error_handler("Form parameters are required")
	end

	local form_data = {
		index = params.form.index or 7,
		name = params.form.name or "Sin",
		display_2d = params.form.display_2d or false,
		subforms = {}
	}

	if not params.subform then
		return err_error_handler("Subform parameters are required")
	end

	local subform_data = {
		index = params.subform.index or 0,
		display_spec_index = params.subform.display_spec_index or 0,
		graph_color = params.subform.graph_color or "c0c0c0",
		points = {}
	}

	if not params.points or #params.points == 0 then
		return err_error_handler("At least one point is required")
	end

	for i, point in ipairs(params.points) do
		if not point.x and not point.y then
			return err_error_handler("Point " .. i .. " must have at least x or y coordinate")
		end

		local point_data = {
			index = point.index or (i - 1),
			x = point.x,
			y = point.y,
			mode = point.mode or "spline"
		}
		table.insert(subform_data.points, point_data)
	end

	table.insert(form_data.subforms, subform_data)
	table.insert(self.data.effects, form_data)

	if not params.effectlines or #params.effectlines == 0 then
		return err_error_handler("At least one effectline is required")
	end

	for i, effectline in ipairs(params.effectlines) do
		if not effectline.fixtures or #effectline.fixtures == 0 then
			return err_error_handler("Effectline " .. i .. " must have at least one fixture")
		end

		local effectline_data = {
			index = effectline.index or (i - 1),
			attribute = effectline.attribute or "DIM",
			blocks = effectline.blocks or 0,
			groups = effectline.groups or 0,
			wings = effectline.wings or 0,
			rate = effectline.rate or 1,
			v1_a = effectline.v1_a or 0,
			v1_b = effectline.v1_b or 0,
			v2_a = effectline.v2_a or 100,
			v2_b = effectline.v2_b or 100,
			phase_a = effectline.phase_a or 0,
			phase_b = effectline.phase_b or -360,
			width_a = effectline.width_a or 100,
			width_b = effectline.width_b or 100,
			pwm_attack = effectline.pwm_attack or 0,
			pwm_decay = effectline.pwm_decay or 0,
			interleave = effectline.interleave or 0,
			flags = {
				absolute_mode = effectline.absolute_mode,
				form_index = effectline.form_index or 7,
				sub_form_index = effectline.sub_form_index or 0,
				reverse = effectline.reverse or false,
				bounce = effectline.bounce or false,
				pwm_type = effectline.pwm_type or "",
				attack = effectline.attack or 0,
				decay = effectline.decay or 0,
				speed_master = effectline.speed_master
			},
			fixtures = effectline.fixtures
		}

		table.insert(self.data.effects, effectline_data)
	end

	return self
end

-- Writes data to a file
--@param data The content to write
--@param filepath The directory path
--@param filename The file name
--@return string The full path to the written file, or error handler result
local function write_to_file(data, filepath, filename)
	local full_path = filepath .. "/" .. filename
	local file = io.open(full_path, "w")
	if not file then
		local success = os.execute('mkdir -p "' .. filepath .. '"')
		if not success then
			return err_error_handler("Could not create directory or open file for writing: " .. full_path)
		end
		file = io.open(full_path, "w")
		if not file then
			return err_error_handler("Could not open file for writing after creating directory: " .. full_path)
		end
	end

	local success, err = file:write(data)
	file:close()

	if not success then
		return err_error_handler("Failed to write to file: " .. err)
	end

	return full_path
end

-- Gets a specific effect by index
--@param index The effect index to retrieve
--@return table|nil The effect data if found, nil otherwise
function FX:get_effect(index)
	for _, effect in ipairs(self.data.effects) do
		if effect.index == index then
			return effect
		end
	end
	return nil
end

-- Gets all effects
--@return table Array of all effect data
function FX:get_all_effects()
	return self.data.effects
end

-- Changes fixture IDs according to the provided mapping
--@param mapping Table mapping source IDs to target IDs
--@return FX self The FX object for method chaining, or error handler result
function FX:change_fixture_ids(mapping)
	if not mapping or type(mapping) ~= "table" then
		return err_error_handler("Invalid fixture mapping provided")
	end

	for _, effect in ipairs(self.data.effects) do
		for _, effectline in ipairs(effect.effectlines) do
			local new_fixtures = {}
			for _, fixture in ipairs(effectline.fixtures) do
				local current_id = fixture:match("^([%d%.]+)")
				if current_id and mapping[current_id] then
					for _, target_id in ipairs(mapping[current_id]) do
						local new_fixture = fixture:gsub("^[%d%.]+", target_id)
						table.insert(new_fixtures, new_fixture)
					end
				else
					table.insert(new_fixtures, fixture)
				end
			end
			effectline.fixtures = new_fixtures
		end
	end

	return self
end

-- Writes an effect to file and imports it
--@param effect_data The effect data to write
--@param target_index The target index (result will be target_index + 1)
--@param selected_effects Optional table of effect indices to process
--@return boolean true on success, or error handler result
function FX:write_and_import_effect(effect_data, target_index, selected_effects)
	if not effect_data or not target_index then
		return err_error_handler("Invalid parameters for write_and_import_effect")
	end

	if not effect_data.forms or not effect_data.effectlines then
		return err_error_handler("Invalid effect data structure")
	end

	-- If selected_effects is provided, check if this effect should be processed
	if selected_effects and not selected_effects[target_index] then
		debug("Skipping effect " .. target_index .. " (not in selection)")
		return true
	end

	local new_index = target_index + 1
	debug("Writing effect to index " .. new_index)

	-- First delete the target effect if it exists
	-- gma.cmd(string.format('Delete Effect %d /nc', new_index))

	local xml_content = [[
<?xml version="1.0" encoding="utf-8"?>
<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60">
	<Info datetime="]] .. os.date("%Y-%m-%dT%H:%M:%S") .. [[" showfile="hardcore_sex_with_animals" />
	<Effect index="]] .. new_index .. [[">
		<Forms>
]]

	for _, form in ipairs(effect_data.forms) do
		if not form.index or not form.name then
			debug("Warning: Invalid form data, skipping")
		else
			xml_content = xml_content .. string.format([[
			<Form index="%d" name="%s" display_2d="%s">
]], form.index, form.name, tostring(form.display_2d):lower())

			for _, subform in ipairs(form.subforms) do
				if not subform.index then
					debug("Warning: Invalid subform data, skipping")
				else
					xml_content = xml_content .. string.format([[
				<SubForm index="%d" display_spec_index="%d" graph_color="%s">
]], subform.index, subform.display_spec_index or 0, subform.graph_color or "c0c0c0")

					for _, point in ipairs(subform.points) do
						if not point.index then
							debug("Warning: Invalid point data, skipping")
						else
							local point_str = string.format([[
						<SubFormPoint index="%d"]], point.index)
							if point.x then point_str = point_str .. string.format(' x="%s"', point.x) end
							if point.y then point_str = point_str .. string.format(' y="%s"', point.y) end
							if point.mode then point_str = point_str .. string.format(' mode="%s"', point.mode) end
							point_str = point_str .. " />\n"
							xml_content = xml_content .. point_str
						end
					end

					xml_content = xml_content .. [[
				</SubForm>
]]
				end
			end

			xml_content = xml_content .. [[
			</Form>
]]
		end
	end

	xml_content = xml_content .. [[
		</Forms>
]]

	for _, effectline in ipairs(effect_data.effectlines) do
		if not effectline.index then
			debug("Warning: Invalid effectline data, skipping")
		else
			xml_content = xml_content .. string.format([[
		<Effectline index="%d" attribute="%s" blocks="%d" groups="%d" wings="%d" rate="%s" v1_a="%s" v1_b="%s" v2_a="%s" v2_b="%s" phase_a="%s" phase_b="%s" width_a="%s" width_b="%s" pwm_attack="%s" pwm_decay="%s" interleave="%s">
			<flags]],
				effectline.index, effectline.attribute or "DIM", effectline.blocks or 0, effectline.groups or 0,
				effectline.wings or 0,
				effectline.rate or 1, effectline.v1_a or 0, effectline.v1_b or 0, effectline.v2_a or 100,
				effectline.v2_b or 100,
				effectline.phase_a or 0, effectline.phase_b or -360, effectline.width_a or 100, effectline.width_b or 100,
				effectline.pwm_attack or 0, effectline.pwm_decay or 0, effectline.interleave or 0)

			-- Add flags only if they are active
			if effectline.flags then
				-- Only include reverse flag if true
				if effectline.flags.reverse then
					xml_content = xml_content .. ' reverse="true"'
				end

				-- Only include bounce flag if true
				if effectline.flags.bounce then
					xml_content = xml_content .. ' bounce="true"'
				end

				-- Always include absolute_mode flag
				xml_content = xml_content .. string.format(' absolute_mode="%s"',
					tostring(effectline.flags.absolute_mode):lower())

				-- Add remaining flags
				xml_content = xml_content .. string.format(' form_index="%d" sub_form_index="%d"',
					effectline.flags.form_index or 7,
					effectline.flags.sub_form_index or 0)

				if effectline.flags.pwm_type and effectline.flags.pwm_type ~= "" then
					xml_content = xml_content .. string.format(' pwm_type="%s"', effectline.flags.pwm_type)
				end

				if effectline.flags.attack and effectline.flags.attack > 0 then
					xml_content = xml_content .. string.format(' attack="%d"', effectline.flags.attack)
				end

				if effectline.flags.decay and effectline.flags.decay > 0 then
					xml_content = xml_content .. string.format(' decay="%d"', effectline.flags.decay)
				end

				if effectline.flags.speed_master then
					xml_content = xml_content .. string.format(' speed_master="%d"', effectline.flags.speed_master)
				end
			else
				-- Default flags if none provided
				xml_content = xml_content .. ' absolute_mode="true" form_index="7" sub_form_index="0"'
			end

			xml_content = xml_content .. [[ />
			<Fixtures>
]]

			for _, fixture in ipairs(effectline.fixtures) do
				xml_content = xml_content .. string.format([[
				<Fixture>%s</Fixture>
]], fixture)
			end

			xml_content = xml_content .. [[
			</Fixtures>
		</Effectline>
]]
		end
	end

	for _, effectdata in ipairs(effect_data.effectdata or {}) do
		if not effectdata.line or not effectdata.fixture then
			debug("Warning: Invalid effectdata, skipping")
		else
			xml_content = xml_content .. string.format([[
		<EFFECTDATA line="%d" fixture="%s" phase="%d" />
]], effectdata.line, effectdata.fixture, effectdata.phase or 0)
		end
	end

	xml_content = xml_content .. [[
	</Effect>
</MA>]]

	local filename = string.format("effect_%d.xml", new_index)
	local filepath = PATH() .. '/effects/'
	local full_path = write_to_file(xml_content, filepath, filename)

	if not full_path then
		return err_error_handler("Failed to write effect file")
	end

	local import_cmd = string.format('Import "%s" at Effect %d /o /nc', filename, new_index)
	gma.cmd(import_cmd)

	return true
end



-- Creates a fixture mapping between two groups
--@param group_a Source group fixtures
--@param group_b Target group fixtures
--@return table Mapping from group_a fixture IDs to group_b fixture IDs, or error handler result
local function create_fixture_mapping(group_a, group_b)
	if not group_a or not group_b or type(group_a) ~= "table" or type(group_b) ~= "table" then
		return err_error_handler("Invalid fixture groups provided")
	end

	if #group_a == 0 or #group_b == 0 then
		return err_error_handler("Fixture groups cannot be empty")
	end


	local mapping = {}
	local group_a_size = #group_a
	local group_b_size = #group_b

	debug("Creating fixture mapping. Group A: " .. group_a_size .. " fixtures, Group B: " .. group_b_size .. " fixtures")

	-- Check if groups are potentially symmetrical (same size or simple multiples)
	local is_symmetrical = false
	if group_a_size == group_b_size then
		is_symmetrical = true
		debug("Groups are symmetrical (same size)")
	elseif group_a_size > group_b_size and group_a_size % group_b_size == 0 then
		is_symmetrical = true
		debug("Groups are symmetrical (Group A is a multiple of Group B)")
	elseif group_b_size > group_a_size and group_b_size % group_a_size == 0 then
		is_symmetrical = true
		debug("Groups are symmetrical (Group B is a multiple of Group A)")
	end

	-- Use direct index mapping for symmetrical groups
	if is_symmetrical then
		debug("Using direct positional mapping for symmetrical groups")
		if group_a_size == group_b_size then
			-- Equal sizes - simple 1:1 mapping by position
			for i = 1, group_a_size do
				local fixture_a = group_a[i]
				local id_a = fixture_a:match("^([%d%.]+)")
				if not id_a then
					debug("Warning: Invalid fixture ID format in group A at index " .. i)
				else
					local id_b = group_b[i]:match("^([%d%.]+)")
					if id_b then
						mapping[id_a] = { id_b }
						debug("Mapped Group A fixture " ..
							id_a .. " (at " .. i .. ") to Group B fixture " .. id_b .. " (at " .. i .. ")")
					else
						debug("Warning: Invalid fixture ID format in group B at index " .. i)
					end
				end
			end
		elseif group_a_size > group_b_size then
			-- Group A larger - map multiple A to single B
			local ratio = group_a_size / group_b_size
			for i = 1, group_a_size do
				local fixture_a = group_a[i]
				local id_a = fixture_a:match("^([%d%.]+)")
				if not id_a then
					debug("Warning: Invalid fixture ID format in group A at index " .. i)
				else
					local b_index = math.floor((i - 1) / ratio) + 1
					local id_b = group_b[b_index]:match("^([%d%.]+)")
					if id_b then
						mapping[id_a] = { id_b }
						debug("Mapped Group A fixture " ..
							id_a .. " (at " .. i .. ") to Group B fixture " .. id_b .. " (at " .. b_index .. ")")
					else
						debug("Warning: Invalid fixture ID format in group B at index " .. b_index)
					end
				end
			end
		else -- group_b_size > group_a_size
			-- Group B larger - map single A to multiple B
			local ratio = group_b_size / group_a_size
			for i = 1, group_a_size do
				local fixture_a = group_a[i]
				local id_a = fixture_a:match("^([%d%.]+)")
				if not id_a then
					debug("Warning: Invalid fixture ID format in group A at index " .. i)
				else
					local mapped_fixtures = {}
					local base_idx = (i - 1) * ratio + 1
					-- Map each A fixture to exactly 'ratio' consecutive B fixtures
					for j = 0, ratio - 1 do
						local b_idx = math.floor(base_idx + j)
						if b_idx <= group_b_size then
							local id_b = group_b[b_idx]:match("^([%d%.]+)")
							if id_b then
								table.insert(mapped_fixtures, id_b)
								debug("  - Added Group B fixture " .. id_b .. " (at " .. b_idx .. ")")
							end
						end
					end
					mapping[id_a] = mapped_fixtures
					debug("Mapped Group A fixture " .. id_a .. " to " .. #mapped_fixtures .. " Group B fixtures")
				end
			end
		end
	else
		-- For non-symmetrical groups, use mirror-symmetrical distribution
		debug("Using mirror-symmetrical mapping for non-symmetrical groups")
		if group_a_size >= group_b_size then
			debug("Group A is larger, creating symmetrical distribution")

			-- For each position in Group A, calculate its mirror pair
			for i = 1, group_a_size do
				local fixture_a = group_a[i]
				local id_a = fixture_a:match("^([%d%.]+)")
				if not id_a then
					debug("Warning: Invalid fixture ID format in group A at index " .. i)
				else
					-- Calculate symmetrical position in Group B
					-- Map from both ends toward middle to maintain symmetry
					local normalized_pos = (i - 0.5) / group_a_size -- 0.0 to 1.0 position
					local b_index = math.floor(normalized_pos * group_b_size) + 1
					if b_index > group_b_size then b_index = group_b_size end

					local mapped_fixtures = {}
					local id_b = group_b[b_index]:match("^([%d%.]+)")
					if id_b then
						table.insert(mapped_fixtures, id_b)
						debug("Mapped Group A fixture " ..
							id_a .. " (at " .. i .. ") to Group B fixture " .. id_b .. " (at " .. b_index .. ")")
					else
						debug("Warning: Invalid fixture ID format in group B at index " .. b_index)
					end

					mapping[id_a] = mapped_fixtures
				end
			end
		else
			debug("Group B is larger, creating symmetrical distribution")

			-- First, calculate how many targets each source gets
			local base_targets = math.floor(group_b_size / group_a_size)
			local extra_targets = group_b_size % group_a_size

			-- Calculate how many targets each position will get
			local targets_per_position = {}
			for i = 1, group_a_size do
				-- Start with base targets for all positions
				targets_per_position[i] = base_targets
			end

			-- Distribute extra targets symmetrically from outside in
			local left = 1
			local right = group_a_size
			while extra_targets > 0 and left <= right do
				if left == right and extra_targets == 1 then
					-- If we have one extra target and we're at the middle position
					targets_per_position[left] = targets_per_position[left] + 1
					extra_targets = 0
				elseif left < right and extra_targets >= 2 then
					-- Add one target to each symmetrical position
					targets_per_position[left] = targets_per_position[left] + 1
					targets_per_position[right] = targets_per_position[right] + 1
					extra_targets = extra_targets - 2
				elseif extra_targets == 1 then
					-- If we have one extra left, add it to the middle-ish position
					local middle = math.ceil(group_a_size / 2)
					targets_per_position[middle] = targets_per_position[middle] + 1
					extra_targets = 0
				else
					break
				end
				left = left + 1
				right = right - 1
			end

			debug("Target distribution: " .. table.concat(targets_per_position, ", "))

			-- Now calculate starting indices for each position
			local start_indices = {}
			local current_index = 1
			for i = 1, group_a_size do
				start_indices[i] = current_index
				current_index = current_index + targets_per_position[i]
			end

			-- Map fixtures using the calculated distribution
			for i = 1, group_a_size do
				local fixture_a = group_a[i]
				local id_a = fixture_a:match("^([%d%.]+)")
				if not id_a then
					debug("Warning: Invalid fixture ID format in group A at index " .. i)
				else
					local mapped_fixtures = {}
					local targets_count = targets_per_position[i]
					local start_idx = start_indices[i]

					debug("Fixture " .. id_a .. " (at " .. i .. ") maps to " .. targets_count ..
						" fixtures starting at " .. start_idx)

					for j = 0, targets_count - 1 do
						local target_idx = start_idx + j
						if target_idx <= group_b_size then
							local id_b = group_b[target_idx]:match("^([%d%.]+)")
							if id_b then
								table.insert(mapped_fixtures, id_b)
								debug("  - Added Group B fixture " .. id_b .. " (at " .. target_idx .. ")")
							else
								debug("Warning: Invalid fixture ID format in group B at index " .. target_idx)
							end
						end
					end

					mapping[id_a] = mapped_fixtures
					debug("Mapped Group A fixture " .. id_a .. " to " .. #mapped_fixtures .. " Group B fixtures")
				end
			end
		end
	end

	return mapping
end

---@class Group
---@field data table Contains group data including id, name, and fixtures
local Group = {}
Group.__index = Group

-- Group class constructor
---@return Group A new Group object instance
function Group.new()
	local self = setmetatable({}, Group)
	self.data = {
		id = nil,
		name = nil,
		fixtures = {}
	}
	return self
end

---@class CloneFilter
---@field world string Range of world values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field all string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field dimmer string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field position string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field gobo string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field color string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field beam string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field focus string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field control string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field shapers string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field video string Range of preset values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field effect string Range of effect values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field sequence string Range of sequence values to clone in MA2 syntax (e.g. "1 Thru 14 - 10 + 15")
---@field clone_all boolean if true clones using single call 

local CloneFilter = {}
CloneFilter.__index = CloneFilter

function CloneFilter.new()
	local self = setmetatable({}, CloneFilter)
	self.world = "*"
	self.all = "*"
	self.dimmer = "*"
	self.position = "*"
	self.gobo = "*"
	self.color = "*"
	self.beam = "*"
	self.focus = "*"
	self.control = "*"
	self.shapers = "*"
	self.video = "*"
	self.effect = "*"
	self.sequence = "*"
	self.clone_all = true
	return self
end

function CloneFilter:get_userinput()
	self.world = gma.textinput("Enter world range", "X Thru Y + Z - A")
	self.all = gma.textinput("Enter preset all range", "X Thru Y + Z - A")
	self.dimmer = gma.textinput("Enter preset dimmer range", "X Thru Y + Z - A")
	self.position = gma.textinput("Enter preset position range", "X Thru Y + Z - A")
	self.gobo = gma.textinput("Enter preset gobo range", "X Thru Y + Z - A")
	self.color = gma.textinput("Enter preset color range", "X Thru Y + Z - A")
	self.beam = gma.textinput("Enter preset beam range", "X Thru Y + Z - A")
	self.focus = gma.textinput("Enter preset focus range", "X Thru Y + Z - A")
	self.control = gma.textinput("Enter preset control range", "X Thru Y + Z - A")
	self.shapers = gma.textinput("Enter preset shapers range", "X Thru Y + Z - A")
	self.video = gma.textinput("Enter preset video range", "X Thru Y + Z - A")
	self.effect = gma.textinput("Enter effect range", "X Thru Y + Z - A")
	self.sequence = gma.textinput("Enter sequence range", "X Thru Y + Z - A")
	self.clone_all = false
end

function CloneFilter:get_userinput_fx_only()
	self.effect = gma.textinput("Enter effect range", "X Thru Y + Z - A")
	self.clone_all = false
end

function CloneFilter:validate_syntax(value)
	if value == "*" then return true end

	local function is_number(str)
		return str:match("^%d+$") ~= nil
	end

	local tokens = {}
	for token in value:gmatch("%S+") do
		table.insert(tokens, token:lower())
	end

	-- Handle empty input
	if #tokens == 0 then
		return err_error_handler("Empty input")
	end

	local i = 1
	while i <= #tokens do
		local token = tokens[i]

		-- Handle Thru
		if token == "thru" then
			-- Check if Thru is at start
			if i == 1 then
				-- Must be followed by a number
				if i + 1 <= #tokens and is_number(tokens[i + 1]) then
					i = i + 2
				else
					return err_error_handler("'Thru' at start must be followed by a number")
				end
			-- Check if Thru is at end
			elseif i == #tokens then
				-- Must be preceded by a number
				if is_number(tokens[i - 1]) then
					i = i + 1
				else
					return err_error_handler("'Thru' at end must be preceded by a number")
				end
			-- Thru in middle
			else
				-- Must have numbers before and after
				if is_number(tokens[i - 1]) and is_number(tokens[i + 1]) then
					i = i + 2
				else
					return err_error_handler("'Thru' must have numbers before and after")
				end
			end
		-- Handle operators
		elseif token == "+" or token == "-" then
			-- Can't be at start or end
			if i == 1 or i == #tokens then
				return err_error_handler("Operators (+/-) cannot be at start or end")
			end
			-- Must have numbers before and after
			if not is_number(tokens[i - 1]) or not is_number(tokens[i + 1]) then
				return err_error_handler("Operators (+/-) must have numbers before and after")
			end
			i = i + 2
		-- Handle numbers
		elseif is_number(token) then
			i = i + 1
		else
			return err_error_handler("Invalid token: " .. token)
		end
	end

	return true
end

-- Executes clone commands based on fixture mapping
---@param fixture_mapping table The mapping of source to target fixtures
---@return boolean|any True on success, or error handler result
function Group:values_clone(fixture_mapping, filter)
	if not fixture_mapping or type(fixture_mapping) ~= "table" then
		return err_error_handler("Invalid fixture mapping provided to values_clone")
	end

	local any_fixtures_cloned = false

	local function clone_values(src_id, target_id, filter_range, attribute_to_clone)
		
		local clone_cmd = string.format("Clone Fixture %s At Fixture %s /nc /pmc /lm if %s%s", src_id, target_id,
		attribute_to_clone, filter_range)

		if filter_range == nil and attribute_to_clone == nil then
			clone_cmd = string.format("Clone Fixture %s At Fixture %s /nc /lm", src_id, target_id)
		end

		debug("Executing: " .. clone_cmd)
		gma.cmd(clone_cmd)
	end

	-- Get ordered list of source fixtures to maintain symmetry
	local source_fixtures = {}
	for src_id, _ in pairs(fixture_mapping) do
		table.insert(source_fixtures, src_id)
	end
	table.sort(source_fixtures)

	debug("Processing " .. #source_fixtures .. " source fixtures symmetrically")

	-- Process fixtures symmetrically from both ends toward middle
	local left = 1
	local right = #source_fixtures
	while left <= right do
		local src_id = source_fixtures[left]
		local target_ids = fixture_mapping[src_id]

		if #target_ids > 0 then
			debug("Cloning source fixture " .. src_id .. " to " .. #target_ids .. " targets")

			for _, target_id in ipairs(target_ids) do
				any_fixtures_cloned = true
				debug("Cloning source " .. src_id .. " to target " .. target_id)

				if filter.clone_all then
					clone_values(src_id, target_id)

				else

				clone_values(src_id, target_id, filter.world, "World ")
				clone_values(src_id, target_id, filter.all, "Preset 0.")
				clone_values(src_id, target_id, filter.dimmer, "Preset 1.")
				clone_values(src_id, target_id, filter.position, "Preset 2.")
				clone_values(src_id, target_id, filter.gobo, "Preset 3.")
				clone_values(src_id, target_id, filter.color, "Preset 4.")
				clone_values(src_id, target_id, filter.beam, "Preset 5.")
				clone_values(src_id, target_id, filter.focus, "Preset 6.")
				clone_values(src_id, target_id, filter.control, "Preset 7.")
				clone_values(src_id, target_id, filter.shapers, "Preset 8.")
				clone_values(src_id, target_id, filter.video, "Preset 9.")
				clone_values(src_id, target_id, filter.effect, "Effect ")
				clone_values(src_id, target_id, filter.sequence, "Sequ ")
				end
			end
		end

		-- Process matching fixture from right side if different (i.e., not the middle fixture in odd-sized groups)
		if left < right then
			src_id = source_fixtures[right]
			target_ids = fixture_mapping[src_id]

			if #target_ids > 0 then
				debug("Cloning source fixture " .. src_id .. " to " .. #target_ids .. " targets")

				for _, target_id in ipairs(target_ids) do
					any_fixtures_cloned = true
					debug("Cloning source " .. src_id .. " to target " .. target_id)


					if filter.clone_all then
						clone_values(src_id, target_id)
	
					else
					clone_values(src_id, target_id, filter.world, "World ")
					clone_values(src_id, target_id, filter.all, "Preset 0.")
					clone_values(src_id, target_id, filter.dimmer, "Preset 1.")
					clone_values(src_id, target_id, filter.position, "Preset 2.")
					clone_values(src_id, target_id, filter.gobo, "Preset 3.")
					clone_values(src_id, target_id, filter.color, "Preset 4.")
					clone_values(src_id, target_id, filter.beam, "Preset 5.")
					clone_values(src_id, target_id, filter.focus, "Preset 6.")
					clone_values(src_id, target_id, filter.control, "Preset 7.")
					clone_values(src_id, target_id, filter.shapers, "Preset 8.")
					clone_values(src_id, target_id, filter.video, "Preset 9.")
					clone_values(src_id, target_id, filter.effect, "Effect ")
					clone_values(src_id, target_id, filter.sequence, "Sequ ")
					end
				end
			end
		else
			-- We've reached the middle fixture in an odd-sized group (left == right)
			-- Add debug message to indicate we're at the middle fixture
			if left == right then
				debug("Processing middle fixture " .. source_fixtures[left] .. " (only once)")
			end
		end

		left = left + 1
		right = right - 1
	end

	if not any_fixtures_cloned then
		return err_error_handler("No fixtures were mapped for cloning")
	end

	return true
end

-- Parses a group from its XML file
---@param group_id number The group ID to parse
---@return Group self The Group object for method chaining, or error handler result
function Group:parse(group_id)
	if not group_id or type(group_id) ~= "number" or group_id <= 0 then
		return err_error_handler("Invalid group ID: " .. tostring(group_id))
	end

	local export_cmd = string.format('Export Group %d "Group %d" /o /nc', group_id, group_id)
	gma.cmd(export_cmd)

	local file_path = PATH() .. "/importexport/Group " .. group_id .. ".xml"
	local file = io.open(file_path, "r")
	if not file then
		return err_error_handler("Could not open file: " .. file_path)
	end

	local content = file:read("*all")
	file:close()

	if not content or content == "" then
		return err_error_handler("Group XML file is empty or corrupted")
	end

	local group_tag = content:match("<Group.-</Group>")
	if not group_tag then
		return err_error_handler("No group found in XML file")
	end

	self.data.id = tonumber(group_tag:match('index="(%d+)"'))
	self.data.name = group_tag:match('name="([^"]+)"')

	if not self.data.id then
		return err_error_handler("Could not parse group ID from XML")
	end

	
	for fixture_tag in group_tag:gmatch('<Subfixture[^>]+/>') do
		local fix_id = fixture_tag:match('fix_id="([^"]+)"')
		local sub_index = fixture_tag:match('sub_index="([^"]+)"')
		
		if not fix_id then
			return err_error_handler("Could not parse fixture ID")
		end
		
		local fixture_str
		if sub_index then
			fixture_str = fix_id .. "." .. sub_index
		else
			fixture_str = fix_id
		end
		
		table.insert(self.data.fixtures, fixture_str)
	end

	if #self.data.fixtures == 0 then
		debug("Warning: Group " .. group_id .. " contains no fixtures")
	end

	return self
end

-- Gets all group data
---@return table The group data (id, name, fixtures)
function Group:get_data()
	return self.data
end

-- Gets the fixtures in the group
---@return table Array of fixture IDs
function Group:get_fixtures()
	return self.data.fixtures
end

-- Gets the group ID
--@return number The group ID
function Group:get_id()
	return self.data.id
end

-- Gets the group name
--@return string The group name
function Group:get_name()
	return self.data.name
end

-- Clones an effect with new fixture data
--@param source_index The index of the effect to clone
--@param target_effect The modified effect data to write
--@return boolean true on success, or error handler result
local function clone_effects(source_index, target_effect)
	if not source_index or not target_effect then
		return err_error_handler("Invalid parameters for clone_effects")
	end

	if not target_effect.forms or not target_effect.effectlines then
		return err_error_handler("Invalid target effect data structure")
	end

	debug("Cloning effect " .. source_index)
	
	-- First export the original effect to get its structure
	local export_cmd = string.format('Export Effect %d "effect_%d_original.xml" /o /nc', source_index, source_index)
	gma.cmd(export_cmd)
	
	-- Now write and import the modified effect
	local fx = FX.new()
	local result = fx:write_and_import_effect(target_effect, source_index)

	if result ~= true then
		return result -- This will be the error handler result
	end

	debug("Effect " .. source_index .. " cloned successfully")
	return true
end

local function process_effects(effects, group_a_set, mapping, group_a_fixtures, group_b_fixtures, preserve_original)
	local effects_modified = 0
	
	-- Loop through each effect to find those using Group A fixtures
	for i = 1, #effects do
		local effect = effects[i]
		if not effect or not effect.index then
			debug("Warning: Invalid effect data, skipping")
		else
			local uses_group_a = false
			local effect_index = effect.index

			-- Create a deep copy of the effect for modification
			local target_effect = deep_copy(effect)
			local modified = false

			-- Temporary storage for effectlines if we need to preserve originals
			local original_effectlines = {}
			if preserve_original then
				-- Store the original effectlines before making any changes
				original_effectlines = deep_copy(target_effect.effectlines or {})
			end

			-- Check each effectline for Group A fixtures
			for j = 1, #(target_effect.effectlines or {}) do
				local effectline = target_effect.effectlines[j]
				if not effectline or not effectline.fixtures then
					debug("Warning: Invalid effectline in effect " .. effect_index .. ", skipping")
				else
					local original_fixtures = effectline.fixtures
					local new_fixtures = {}
					local line_modified = false

					-- We only need to track used fixtures when Group A > Group B to prevent duplicates
					local used_target_fixtures = {}
					local should_track_used = #group_a_fixtures >= #group_b_fixtures

					debug("Processing effect " .. effect_index .. " with " .. #original_fixtures .. " fixtures")

					-- Process each fixture in the effectline
					for k = 1, #original_fixtures do
						local fixture = original_fixtures[k]
						if not fixture then
							debug("Warning: Invalid fixture in effectline, skipping")
						else
							local current_id = fixture:match("^([%d%.]+)")

							if current_id and group_a_set[current_id] then
								-- This fixture is in Group A, map it to Group B
								uses_group_a = true
								line_modified = true

								if mapping[current_id] and #mapping[current_id] > 0 then
									debug("Processing fixture " ..
										current_id .. " with " .. #mapping[current_id] .. " mapped fixtures")

									for idx, target_id in ipairs(mapping[current_id]) do
										-- Only check for used fixtures when Group A > Group B
										if target_id and (not should_track_used or not used_target_fixtures[target_id]) then
											local new_fixture = fixture:gsub("^[%d%.]+", target_id)
											table.insert(new_fixtures, new_fixture)
											debug("Added mapped fixture " ..
												target_id .. " to effect (map index " .. idx .. ")")

											if should_track_used then
												used_target_fixtures[target_id] = true -- Mark this target fixture as used
											end
										end
									end
								else
									debug("Warning: No mapping found for fixture " .. current_id)
								end
							else
								-- Keep non-Group A fixtures as they are
								table.insert(new_fixtures, fixture)
								debug("Kept non-Group A fixture " .. (current_id or "unknown"))
							end
						end
					end

					if line_modified then
						effectline.fixtures = new_fixtures
						modified = true
						debug("Modified effectline now has " .. #new_fixtures .. " fixtures")
					end
				end
			end

			-- If we want to preserve originals and the effect was modified,
			-- append the original effectlines to the modified effect
			if preserve_original and modified then
				debug("Preserving original effectlines by duplicating them")
				-- Find the highest index in current effectlines
				local highest_index = 0
				for _, effectline in ipairs(target_effect.effectlines) do
					if effectline.index > highest_index then
						highest_index = effectline.index
					end
				end

				-- Clone the original effectlines with new indices
				for _, original_line in ipairs(original_effectlines) do
					if original_line and original_line.fixtures and #original_line.fixtures > 0 then
						highest_index = highest_index + 1
						local cloned_line = deep_copy(original_line)
						cloned_line.index = highest_index

						-- We might want to mark the cloned lines in some way
						-- For example, add "ORIGINAL" to attribute name if possible
						if cloned_line.attribute then
							cloned_line.attribute = cloned_line.attribute
						end

						debug("Adding preserved original effectline with new index " .. highest_index)
						table.insert(target_effect.effectlines, cloned_line)
					end
				end
			end

			if uses_group_a and modified then
				debug("Cloning effect " .. effect_index .. " (uses Group A fixtures)")
				local success = clone_effects(effect_index, target_effect)
				if not success then
					return err_error_handler("Failed to clone effect " .. effect_index)
				end
				effects_modified = effects_modified + 1
			end
		end
	end
	
	return effects_modified
end

-- Main function for cloning effects with fixture mapping
--@param group_a_id number|nil The source group ID. If nil, will prompt user for input
--@param group_b_id number|nil The target group ID. If nil, will prompt user for input
--@param clone_all boolean Whether to clone all effects or prompt for specific effect
--@return nil on normal completion, or error handler result on failure
function CLONE(group_a_id, group_b_id, clone_all)
	-- set drive to internal
	gma.cmd('SD 1')
	if not gma.gui.confirm('WARNING', 'Please create a backup of your show before running clonning. Press Confirm to proceed.') then
		debug("User cancelled backup warning confirmation")
		return
	end
	if group_a_id == nil then
		group_a_id = tonumber(gma.textinput("Enter Group A ID", ""))
	end
	if group_b_id == nil then
		group_b_id = tonumber(gma.textinput("Enter Group B ID", ""))
	end

	if not group_a_id or not group_b_id then
		return err_error_handler("Invalid group IDs provided")
	end

	if group_a_id == group_b_id then
		return err_error_handler("Group A and Group B cannot be the same")
	end

	-- Ask if user wants to preserve original effectlines
	local preserve_original = gma.gui.confirm('Duplicate Effectlines',
		'Do you want to keep the original effect lines alongside the new ones?')
	if preserve_original then
		debug("User chose to duplicate effectlines and preserve originals")
	else
		debug("User chose to replace original effectlines")
	end
	local fx_cloning_style = 0

	local cloning_style = gma.gui.confirm("Cloning style", "[OK] for XML, [CANCEL] for MA2")
	if cloning_style then
		fx_cloning_style = 1
	else
		fx_cloning_style = 2
	end
	
	if fx_cloning_style == 1 then
		local full_clone = gma.gui.confirm("XML Cloning style", "[OK] for Full, [CANCEL] for Effects Only")
		if not full_clone then
			fx_cloning_style = 3
		end
	end

	if fx_cloning_style == 0 then
		return err_error_handler("Invalid cloning style. Got 0")
	end

	local group_a = Group.new():parse(group_a_id)
	if type(group_a) == "string" then
		return err_error_handler("Failed to parse Group A: " .. group_a)
	end

	local group_b = Group.new():parse(group_b_id)
	if type(group_b) == "string" then
		return err_error_handler("Failed to parse Group B: " .. group_b)
	end

	local group_a_fixtures = group_a:get_fixtures()
	if not group_a_fixtures then
		return err_error_handler("Failed to get fixtures from Group A")
	end

	local group_b_fixtures = group_b:get_fixtures()
	if not group_b_fixtures then
		return err_error_handler("Failed to get fixtures from Group B")
	end

	if #group_a_fixtures == 0 then
		return err_error_handler("Group A contains no fixtures")
	end

	if #group_b_fixtures == 0 then
		return err_error_handler("Group B contains no fixtures")
	end

	local mapping = create_fixture_mapping(group_a_fixtures, group_b_fixtures)
	if not mapping then
		return err_error_handler("Failed to create fixture mapping")
	end


	local clone_filter = CloneFilter.new()
	if fx_cloning_style == 3 then
		clone_filter:get_userinput_fx_only()
	elseif not gma.gui.confirm("Do you want to clone everything?", "[ok] Clone all data from Group A to Group B \n[cancel] To select specific ranges") then
		clone_filter:get_userinput()
	end
	-- Validate all filter values
	local filter_fields = {
		"world", "all", "dimmer", "position", "gobo",
		"color", "beam", "focus", "control",
		"shapers", "video", "effect", "sequence"
	}

	for _, field in ipairs(filter_fields) do
		local validation_result = clone_filter:validate_syntax(clone_filter[field])
		if validation_result ~= true then
			err_error_handler("Invalid syntax in " .. field .. " filter")
		end
	end

	local fx_pool = FX.new():parse(clone_filter.effect)
	if type(fx_pool) == "string" then
		return err_error_handler("Failed to parse effects: " .. fx_pool)
	end

	-- Create a set of Group A fixture IDs for quick lookup
	local group_a_set = {}
	for _, fixture in ipairs(group_a_fixtures) do
		local id = fixture:match("^([%d%.]+)")
		if id then
			group_a_set[id] = true
		end
	end

	-- Get all effects from the pool
	local effects = fx_pool:get_all_effects()
	if not effects or #effects == 0 then
		return err_error_handler("No effects found in the effect pool")
	end

	debug("Found " .. #effects .. " effects in the pool")

	-- Clone fixture values from Group A to Group B if not doing effects only
	debug("Cloning fixture values from Group A to Group B")
	local values_clone_result = group_a:values_clone(mapping, clone_filter)
	if values_clone_result ~= true then
		return values_clone_result
	end

	local effects_modified = 0
	if fx_cloning_style ~= 2 then
		effects_modified = process_effects(effects, group_a_set, mapping, group_a_fixtures, group_b_fixtures, preserve_original)
		if type(effects_modified) == "string" then
			return effects_modified -- This will be the error handler result
		end
	end

	local message = ""
	if fx_cloning_style == 1 then
		message = "XML+MA2 cloning complete"
	elseif fx_cloning_style == 2 then
		message = "MA2 cloning complete"
	else
		message = "XML Effects Only cloning complete"
	end

	if effects_modified ~= nil or effects_modified ~= 0 then
		gma.gui.msgbox(message,
		'Successfully modified ' ..
		effects_modified ..
		' effects. \nPlease verify updated effects and values. \n\nThanks for using AlphaBetaCharlieFox3 Edition! \nMade By Kostiantyn Yerokhin')
	else
		gma.gui.msgbox("No effects modified", "No effects using Group A fixtures were found. Fixture values were cloned.")
	end

	debug("CLONE function completed successfully")
	return name
end

-- Returns the main CLONE function for plugin execution
--@return function The CLONE function
return CLONE
