return function(import)
	local Theme = import("Core/Theme")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Animation = import("Services/Animation")

	local Editable = {}

	function Editable.Attach(cleanup, box, text, opts)
		opts = opts or {}
		local handle = { Editing = false, Enabled = opts.Enabled ~= false, Committed = Signal.new() }
		cleanup:Add(handle.Committed)
		local original
		local lastClick = 0
		local underline

		local function highlight(active)
			if not opts.Highlight then
				return
			end
			if active and not underline then
				underline = Utility.Create("Frame", {
					Name = "EditLine",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.Get("Accent"),
					Parent = box,
				})
			elseif not active and underline then
				underline:Destroy()
				underline = nil
			end
		end

		local function finish(commit)
			if not handle.Editing then
				return
			end
			handle.Editing = false
			box.TextEditable = false
			box.Selectable = false
			highlight(false)
			local value = box.Text
			if commit and value ~= original then
				local valid = true
				if opts.Validate then
					local ok, result = pcall(opts.Validate, value)
					valid = ok and result ~= false
				end
				if valid then
					if opts.OnCommit then
						Utility.SafeCall(opts.Label or "Editable", opts.OnCommit, value)
					end
					handle.Committed:Fire(value)
				else
					Animation:Play(box, { TextColor3 = Theme.Get("Error") }, { Duration = 0.1 })
					task.delay(0.45, function()
						if box.Parent then
							text.SetColor(opts.Color or "Text")
						end
					end)
					value = original
				end
			elseif not commit then
				value = original
			end
			text.SetText(opts.Source and opts.Source() or value)
		end

		function handle.Begin()
			if not handle.Enabled or handle.Editing or not box.Parent then
				return
			end
			handle.Editing = true
			original = opts.Source and opts.Source() or text.Source
			box.RichText = false
			box.Text = original
			box.TextEditable = true
			box.Selectable = true
			highlight(true)
			box:CaptureFocus()
			pcall(function()
				box.CursorPosition = #original + 1
				box.SelectionStart = 1
			end)
		end

		function handle.Cancel()
			finish(false)
		end

		function handle.SetEnabled(value)
			handle.Enabled = value == true
			if not handle.Enabled then
				finish(false)
			end
		end

		cleanup:Add(box.FocusLost:Connect(function(enter)
			finish(enter or opts.CommitOnFocusLost ~= false)
		end))

		cleanup:Add(box.InputBegan:Connect(function(input)
			if handle.Editing or not handle.Enabled then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local now = os.clock()
			if now - lastClick < 0.4 then
				lastClick = 0
				handle.Begin()
			else
				lastClick = now
			end
		end))

		if opts.Trigger then
			cleanup:Add(opts.Trigger.Activated:Connect(function()
				handle.Begin()
			end))
		end

		box.TextEditable = false
		box.ClearTextOnFocus = false
		box.Selectable = false
		return handle
	end

	return Editable
end
