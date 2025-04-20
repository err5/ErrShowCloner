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
	local error_msg = tostring(err)
    
	local continue = gma.gui.confirm(
		"Error",
		error_msg .. "\n\nPress [OK] to continue\nPress [CANCEL] to terminate plugin"
	)
    
	if continue then
		debug("User chose to continue after error: " .. error_msg)
		return "CONTINUE"
	else
		debug("User chose to terminate after error: " .. error_msg)
		error("Plugin terminated by user")
	end
end

local PATH = function()
	return gma.show.getvar('PATH')
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

local FX = {}
FX.__index = FX

function FX.new()
	local self = setmetatable({}, FX)
	self.data = {
		effects = {}
	}
	return self
end

function FX:parse()
	gma.cmd('Export Effect 1 Thru 9999 "effect_pool.xml"')
	
	gma.sleep(0.3)
	
	local file_path = PATH() .. "/effects/effect_pool.xml"
	local file = io.open(file_path, "r")
	if not file then
		return err_error_handler("Could not open file: " .. file_path)
	end

	local content = file:read("*all")
	file:close()

	for effect_tag in content:gmatch("<Effect.-</Effect>") do
		local effect_data = {
			index = tonumber(effect_tag:match('index="(%d+)"')),
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
				interleave = tonumber(effectline:match('interleave="([^"]+)"')),
				flags = {
					absolute_mode = effectline:match('absolute_mode="([^"]+)"') == "true",
					form_index = tonumber(effectline:match('form_index="(%d+)"')),
					sub_form_index = tonumber(effectline:match('sub_form_index="(%d+)"')),
					pwm_type = effectline:match('pwm_type="([^"]+)"'),
					attack = tonumber(effectline:match('attack="(%d+)"')),
					decay = tonumber(effectline:match('decay="(%d+)"'))
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
	end

	return self
end

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
				absolute_mode = effectline.absolute_mode or true,
				form_index = effectline.form_index or 7,
				sub_form_index = effectline.sub_form_index or 0
			},
			fixtures = effectline.fixtures
		}

		table.insert(self.data.effects, effectline_data)
	end

	return self
end

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



function FX:get_effect(index)
	for _, effect in ipairs(self.data.effects) do
		if effect.index == index then
			return effect
		end
	end
	return nil
end

function FX:get_all_effects()
	return self.data.effects
end

function FX:change_fixture_ids(mapping)
	if not mapping or type(mapping) ~= "table" then
		return err_error_handler("Invalid fixture mapping provided")
	end

	for _, effect in ipairs(self.data.effects) do
		for _, effectline in ipairs(effect.effectlines) do
			local new_fixtures = {}
			for _, fixture in ipairs(effectline.fixtures) do
				local current_id = fixture:match("^(%d+)")
				if current_id and mapping[current_id] then
					for _, target_id in ipairs(mapping[current_id]) do
						local new_fixture = fixture:gsub("^%d+", target_id)
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

function FX:write_and_import_effect(effect_data, target_index)
    if not effect_data or not target_index then
        return err_error_handler("Invalid parameters for write_and_import_effect")
    end

    if not effect_data.forms or not effect_data.effectlines then
        return err_error_handler("Invalid effect data structure")
    end

    local new_index = target_index + 1
    debug("Writing effect to index " .. new_index)

    local xml_content = [[
<?xml version="1.0" encoding="utf-8"?>
<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60">
	<Info datetime="]] .. os.date("%Y-%m-%dT%H:%M:%S") .. [[" showfile="atlas plugin testing" />
	<Effect index="]] .. new_index .. [[">
		<Forms>
]]

    for _, form in ipairs(effect_data.forms) do
        if not form.index or not form.name then
            debug("Warning: Invalid form data, skipping")
            goto continue_form
        end

        xml_content = xml_content .. string.format([[
			<Form index="%d" name="%s" display_2d="%s">
]], form.index, form.name, tostring(form.display_2d):lower())

        for _, subform in ipairs(form.subforms) do
            if not subform.index then
                debug("Warning: Invalid subform data, skipping")
                goto continue_subform
            end

            xml_content = xml_content .. string.format([[
				<SubForm index="%d" display_spec_index="%d" graph_color="%s">
]], subform.index, subform.display_spec_index or 0, subform.graph_color or "c0c0c0")

            for _, point in ipairs(subform.points) do
                if not point.index then
                    debug("Warning: Invalid point data, skipping")
                    goto continue_point
                end

                local point_str = string.format([[
					<SubFormPoint index="%d"]], point.index)
                if point.x then point_str = point_str .. string.format(' x="%s"', point.x) end
                if point.y then point_str = point_str .. string.format(' y="%s"', point.y) end
                if point.mode then point_str = point_str .. string.format(' mode="%s"', point.mode) end
                point_str = point_str .. " />\n"
                xml_content = xml_content .. point_str
                ::continue_point::
            end

            xml_content = xml_content .. [[
				</SubForm>
]]
            ::continue_subform::
        end

        xml_content = xml_content .. [[
			</Form>
]]
        ::continue_form::
    end

    xml_content = xml_content .. [[
		</Forms>
]]

    for _, effectline in ipairs(effect_data.effectlines) do
        if not effectline.index then
            debug("Warning: Invalid effectline data, skipping")
            goto continue_effectline
        end

        xml_content = xml_content .. string.format([[
		<Effectline index="%d" attribute="%s" blocks="%d" groups="%d" wings="%d" rate="%s" v1_a="%s" v1_b="%s" v2_a="%s" v2_b="%s" phase_a="%s" phase_b="%s" width_a="%s" width_b="%s" pwm_attack="%s" pwm_decay="%s" interleave="%s">
			<flags absolute_mode="%s" form_index="%d" sub_form_index="%d" pwm_type="%s" attack="%d" decay="%d" />
			<Fixtures>
]], 
            effectline.index, effectline.attribute or "DIM", effectline.blocks or 0, effectline.groups or 0, effectline.wings or 0,
            effectline.rate or 1, effectline.v1_a or 0, effectline.v1_b or 0, effectline.v2_a or 100, effectline.v2_b or 100,
            effectline.phase_a or 0, effectline.phase_b or -360, effectline.width_a or 100, effectline.width_b or 100,
            effectline.pwm_attack or 0, effectline.pwm_decay or 0, effectline.interleave or 0,
            tostring(effectline.flags and effectline.flags.absolute_mode or true):lower(), 
            effectline.flags and effectline.flags.form_index or 7, 
            effectline.flags and effectline.flags.sub_form_index or 0,
            effectline.flags and effectline.flags.pwm_type or "", 
            effectline.flags and effectline.flags.attack or 0, 
            effectline.flags and effectline.flags.decay or 0)

        for _, fixture in ipairs(effectline.fixtures) do
            xml_content = xml_content .. string.format([[
				<Fixture>%s</Fixture>
]], fixture)
        end

        xml_content = xml_content .. [[
			</Fixtures>
		</Effectline>
]]
        ::continue_effectline::
    end

    for _, effectdata in ipairs(effect_data.effectdata or {}) do
        if not effectdata.line or not effectdata.fixture then
            debug("Warning: Invalid effectdata, skipping")
            goto continue_effectdata
        end

        xml_content = xml_content .. string.format([[
		<EFFECTDATA line="%d" fixture="%s" phase="%d" />
]], effectdata.line, effectdata.fixture, effectdata.phase or 0)
        ::continue_effectdata::
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
    
    gma.sleep(0.05)
    
    return true
end

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
    
    -- Create direct fixture pairs based on relative positions
    for i, fixture_a in ipairs(group_a) do
        local id_a = fixture_a:match("^(%d+)")
        if not id_a then
            return err_error_handler("Invalid fixture ID format in group A")
        end
        
        -- Calculate corresponding fixtures in group B
        local mapped_fixtures = {}
        local ratio = group_b_size / group_a_size
        local start_idx = math.floor((i - 1) * ratio) + 1
        local end_idx = math.floor(i * ratio)
        
        -- Ensure we have at least one fixture
        if start_idx > end_idx then
            start_idx = end_idx
        end
        
        -- Add all corresponding fixtures
        for j = start_idx, end_idx do
            if j <= group_b_size then
                local id_b = group_b[j]:match("^(%d+)")
                if not id_b then
                    return err_error_handler("Invalid fixture ID format in group B")
                end
                table.insert(mapped_fixtures, id_b)
            end
        end
        
        -- Always ensure at least one fixture is mapped
        if #mapped_fixtures == 0 and group_b_size > 0 then
            local id_b = group_b[1]:match("^(%d+)")
            table.insert(mapped_fixtures, id_b)
        end
        
        mapping[id_a] = mapped_fixtures
    end

	return mapping
end

local Group = {}
Group.__index = Group

function Group.new()
	local self = setmetatable({}, Group)
	self.data = {
		id = nil,
		name = nil,
		fixtures = {}
	}
	return self
end

function Group:parse(group_id)
	local export_cmd = string.format('Export Group %d "Group %d"', group_id, group_id)
	gma.cmd(export_cmd)
	
	gma.sleep(0.05)
	
	local file_path = PATH() .. "/importexport/Group " .. group_id .. ".xml"
	local file = io.open(file_path, "r")
	if not file then
		return err_error_handler("Could not open file: " .. file_path)
	end

	local content = file:read("*all")
	file:close()

	local group_tag = content:match("<Group.-</Group>")
	if not group_tag then
		return err_error_handler("No group found in XML file")
	end

	self.data.id = tonumber(group_tag:match('index="(%d+)"'))
	self.data.name = group_tag:match('name="([^"]+)"')

	for fixture in group_tag:gmatch('<Subfixture fix_id="([^"]+)"') do
		table.insert(self.data.fixtures, fixture)
	end

	return self
end

function Group:get_data()
	return self.data
end

function Group:get_fixtures()
	return self.data.fixtures
end

function Group:get_id()
	return self.data.id
end

function Group:get_name()
	return self.data.name
end

local function clone_effects(source_index, target_effect)
    if not source_index or not target_effect then
        return err_error_handler("Invalid parameters for clone_effects")
    end
    debug("Cloning effect " .. source_index)
    local fx = FX.new()
    fx:write_and_import_effect(target_effect, source_index)
    debug("Effect " .. source_index .. " cloned successfully")
end

function CLONE()
    local group_a_id = tonumber(gma.textinput("Enter Group A ID", ""))
    local group_b_id = tonumber(gma.textinput("Enter Group B ID", ""))
    
    if not group_a_id or not group_b_id then
        return err_error_handler("Invalid group IDs provided")
    end

    -- Parse groups and create mapping
    local group_a = Group.new():parse(group_a_id)
    local group_b = Group.new():parse(group_b_id)
    local mapping = create_fixture_mapping(group_a:get_fixtures(), group_b:get_fixtures())
    
    -- Define non-group fixtures
    local non_group_fixtures = {34,35,38,39,42,43,46,47}
    local non_group_set = {}
    for _, id in ipairs(non_group_fixtures) do
        non_group_set[tostring(id)] = true
    end
    
    -- Parse effects and modify them
    local fx_pool = FX.new():parse()
    local modified_count = 0
    
    for _, effect in ipairs(fx_pool:get_all_effects()) do
        if not effect.index then goto continue end
        
        -- Check if effect uses Group A fixtures
        local uses_group_a = false
        for _, line in ipairs(effect.effectlines) do
            for _, fixture in ipairs(line.fixtures) do
                local id = fixture:match("^(%d+)")
                if id and mapping[id] then
                    uses_group_a = true
                    break
                end
            end
            if uses_group_a then break end
        end
        
        if not uses_group_a then goto continue end
        
        -- Clone the effect
        local modified = deep_copy(effect)
        
        -- Process each effect line
        for _, line in ipairs(modified.effectlines) do
            -- Directly replace each Group A fixture with its Group B pairs
            local new_fixtures = {}
            local idx = 1
            
            for i, fixture in ipairs(line.fixtures) do
                local id = fixture:match("^(%d+)")
                
                if id and non_group_set[id] then
                    -- Keep non-group fixtures as is
                    new_fixtures[idx] = fixture
                    idx = idx + 1
                elseif id and mapping[id] then
                    -- Replace with all mapped fixtures
                    for _, target_id in ipairs(mapping[id]) do
                        local new_fixture = fixture:gsub("^%d+", target_id)
                        new_fixtures[idx] = new_fixture
                        idx = idx + 1
                    end
                else
                    -- Keep other fixtures as is
                    new_fixtures[idx] = fixture
                    idx = idx + 1
                end
            end
            
            line.fixtures = new_fixtures
        end
        
        if clone_effects(effect.index, modified) then
            modified_count = modified_count + 1
        end
        
        ::continue::
    end
    
    debug("CLONE completed: " .. modified_count .. " effects modified")
end





return CLONE
