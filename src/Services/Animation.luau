return function(import)
	local TweenService = game:GetService("TweenService")

	local Animation = {
		Enabled = true,
		Duration = { Instant = 0.07, Fast = 0.14, Normal = 0.24, Slow = 0.38 },
		Stagger = 0.022,
	}

	Animation.Ease = {
		Smooth = { Style = Enum.EasingStyle.Quint, Direction = Enum.EasingDirection.Out },
		Soft = { Style = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.Out },
		Snap = { Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		Glide = { Style = Enum.EasingStyle.Cubic, Direction = Enum.EasingDirection.InOut },
		Linear = { Style = Enum.EasingStyle.Linear, Direction = Enum.EasingDirection.Out },
	}

	local active = setmetatable({}, { __mode = "k" })

	local function resolve(opts)
		local ease = opts.Ease and Animation.Ease[opts.Ease] or Animation.Ease.Smooth
		return opts.Style or ease.Style, opts.Direction or ease.Direction
	end

	function Animation:Play(object, props, opts)
		opts = opts or {}
		if not Animation.Enabled or opts.Duration == 0 then
			for property, value in props do
				object[property] = value
			end
			if opts.OnComplete then
				task.defer(opts.OnComplete)
			end
			return nil
		end

		local list = active[object]
		if not list then
			list = {}
			active[object] = list
		end
		for index = #list, 1, -1 do
			local entry = list[index]
			for property in props do
				if entry.props[property] then
					entry.tween:Cancel()
					table.remove(list, index)
					break
				end
			end
		end

		local style, direction = resolve(opts)
		local info = TweenInfo.new(
			opts.Duration or Animation.Duration.Normal,
			style,
			direction,
			0,
			false,
			opts.Delay or 0
		)
		local tween = TweenService:Create(object, info, props)
		local entry = { tween = tween, props = props }
		table.insert(list, entry)
		tween.Completed:Once(function(state)
			local position = table.find(list, entry)
			if position then
				table.remove(list, position)
			end
			if opts.OnComplete and state == Enum.PlaybackState.Completed then
				opts.OnComplete()
			end
		end)
		tween:Play()
		return tween
	end

	function Animation:Snap(object, props, opts)
		opts = opts or {}
		opts.Ease = "Snap"
		opts.Duration = opts.Duration or Animation.Duration.Normal
		return Animation:Play(object, props, opts)
	end

	function Animation:Soft(object, props, duration)
		return Animation:Play(object, props, { Ease = "Soft", Duration = duration or Animation.Duration.Fast })
	end

	function Animation:Tween(object, props, duration, style, direction)
		return Animation:Play(object, props, { Duration = duration, Style = style, Direction = direction })
	end

	function Animation:Sequence(items, build, opts)
		opts = opts or {}
		local gap = opts.Stagger or Animation.Stagger
		local limit = opts.Limit or 16
		for index, item in items do
			if index > limit then
				build(item, index, 0)
			else
				build(item, index, (index - 1) * gap)
			end
		end
	end

	function Animation:Cancel(object)
		local list = active[object]
		if list then
			for _, entry in list do
				entry.tween:Cancel()
			end
			table.clear(list)
		end
	end

	function Animation:CancelTree(root)
		if not root then
			return
		end
		Animation:Cancel(root)
		for _, descendant in root:GetDescendants() do
			Animation:Cancel(descendant)
		end
	end

	return Animation
end
