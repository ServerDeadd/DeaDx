local DeaDx = getgenv().__DeaDx

local loader = DeaDx:CreateLoadingScreen({
	Title = "DeaDx",
	Subtitle = "preparando o hub",
	Icon = "zap",
	TitleGradient = { "#FF2D40", "#FFFFFF" },
	Gradient = { "#FF2D40", "#FACC15" },
	Steps = { "Verificando ambiente", "Carregando icones", "Montando interface" },
	Tips = { "Segure a barra do topo para arrastar a janela" },
	Footer = "by ServerDead",
})

loader:Run({
	function()
		DeaDx:Integrity()
	end,
	function()
		DeaDx:ListIcons()
	end,
	function()
		task.wait(0.15)
	end,
})

loader.Finished:Connect(function()
	local key = DeaDx:CreateKeySystem({
		Title = "DeaDx",
		Subtitle = "Insira a chave ou cumpra um requisito",
		Icon = "key-round",
		Note = "Entre no grupo ou use a chave do canal #chaves.",
		Salt = "ServerDead",
		Hashes = { DeaDx:Hash("DEADX-2026", "ServerDead") },
		Group = 1069605852,
		Whitelist = { "ServerDead" },
		Require = "any",
		Link = "https://discord.gg/deadx",
		Attempts = 3,
		Lockout = 10,
		Remember = false,
		Integrity = true,
		OnSuccess = function()
			DeaDx:Notify({ Title = "Bem-vindo", Content = "Acesso liberado.", Type = "Success" })
		end,
	})
end)
