return function(import)
	local Component = import("Core/Component")

	local Label = setmetatable({}, { __index = Component.Base })
	Label.__index = Label

	function Label:SetText(text)
		return self:SetTitle(text)
	end

	return function(ctx, id, config)
		if type(config.Title) ~= "string" and type(config.Text) == "string" then
			config.Title = config.Text
		end
		return Component.New(ctx, Label, "Label", id, config, { MinHeight = 38, Flat = config.Flat ~= false })
	end
end
