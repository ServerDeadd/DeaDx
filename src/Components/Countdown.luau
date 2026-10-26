return function(import)
	local Progress = import("Components/Progress")

	return function(ctx, id, config)
		config.Mode = "Countdown"
		config.Seconds = config.Seconds or 60
		return Progress(ctx, id, config)
	end
end
