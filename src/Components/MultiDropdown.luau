return function(import)
	local Dropdown = import("Components/Dropdown")

	return function(ctx, id, config)
		config.Multi = true
		return Dropdown(ctx, id, config)
	end
end
