# DeaDx

Biblioteca de UI para Roblox por **ServerDead**.

O código é modular (`src/` com `Core`, `Components`, `Services`, `Icons`, `Themes`). O `DeaDx.lua` na raiz é só a saída do build, gerada por `build.ps1` para quem quer um arquivo só.

```lua
-- modular: baixa os módulos do repo
local DeaDx = loadstring(game:HttpGet("https://raw.githubusercontent.com/ServerDeadd/DeaDx/main/src/init.luau"))()

-- ou o build de arquivo único, sem HTTP interno
local DeaDx = loadstring(game:HttpGet("https://raw.githubusercontent.com/ServerDeadd/DeaDx/main/DeaDx.lua"))()
```

---

## Índice

1. [Janela](#janela) · 2. [Tabs e sections](#tabs-sub-tabs-sections-e-cards) · 3. [Componentes](#componentes) · 4. [Dropdown editável](#dropdown-editável) · 5. [Preview 3D / ESP](#preview-3d--esp) · 6. [Cooldown e cadeado](#cooldown-e-cadeado) · 7. [Progress e countdown](#progress-e-countdown) · 8. [Colorpicker](#colorpicker) · 9. [Ícones](#ícones) · 10. [Cores de texto](#cores-de-texto-markup) · 11. [Status bar](#status-bar) · 12. [Notificações](#notificações-e-diálogos) · 13. [Key system](#key-system) · 13b. [Luarmor](#luarmor) · 13c. [Key+](#key) · 14. [Loading screen](#loading-screen) · 15. [Dependências](#dependências-entre-componentes) · 16. [Menu de contexto](#menu-de-contexto) · 17. [Command palette](#command-palette) · 18. [Desfazer/refazer](#desfazer-e-refazer) · 19. [Tour guiado](#tour-guiado) · 20. [Console](#console-de-logs) · 21. [Painel de configs](#painel-de-configs) · 22. [Painel de teclas](#painel-de-teclas) · 23. [Gráfico](#gráfico-ao-vivo) · 24. [Temas](#temas) · 25. [Animações](#animações) · 26. [Config](#config) · 27. [Anti-hook](#anti-hook)

---

## Janela

```lua
local Window = DeaDx:CreateWindow({
    Title = "DeaDx",
    SubTitle = "by ServerDead",
    Icon = "zap",
    Size = UDim2.fromOffset(620, 460),
    Theme = "DeaDx",
    Acrylic = true,
    Resize = true,
    Search = true,
    Footer = "v1.0.0",
    MinimizeKey = Enum.KeyCode.RightControl,
    LockTheme = "DeaDx",   -- trava o tema (o usuário não troca)
    LockScale = 1,          -- trava a escala da UI
})
```

| Campo | Padrão | O que faz |
| --- | --- | --- |
| `Title` `SubTitle` `Icon` `IconColor` | — | topo da janela |
| `Size` `Position` `MinSize` `MaxSize` | 580x440 | tamanho e limites |
| `Theme` `Font` `Scale` | DeaDx / Gotham / 1 | aparência inicial |
| `LockTheme` `LockScale` | — | trava tema/escala para o usuário final |
| `Acrylic` `Blur` `Glass` | true | fundo translúcido + vidro 3D real |
| `Background` | — | `{ Image, Transparency, Color, Gradient, ScaleType }` |
| `Resize` `Search` | true | alça de redimensionar, busca |
| `CloseButton` `CollapseButton` | true | botões do topo |
| `MaximizeButton` `ConfirmClose` | false | extras do topo |
| `RestoreButton` | true | pílula flutuante quando minimizado |
| `PopupsOutside` | false | dropdowns podem sair da janela |
| `MinimizeKey` `SaveFile` `OnClose` | — | tecla, nome do config, callback |

Métodos: `SelectTab` `GetTab` `SetTitle` `SetTitleColor` `SetSubTitle` `SetIcon` `SetFooter` `SetTheme` `SetSearchEnabled` `SetBackground` `SetBackgroundImage` `SetAcrylic` `SetTransparency` `SetMinimizeKey` `SetCollapsed` `ToggleCollapsed` `SetMaximized` `Minimize` `Restore` `Toggle` `IsMinimized` `Notify` `CreateDialog` `Save` `Load` `SetAutoSave` `Destroy`.

O recolher sobe (mantém o topo no lugar) em vez de encolher pro meio.

---

## Tabs, sub-tabs, sections e cards

```lua
local Main = Window:AddTab({ Title = "Main", Icon = "house", IconColor = "#FF2D40" })

local Combat = Main:AddSection({ Title = "Combat", Icon = "sword", Collapsible = true })
local Card   = Main:AddCard({ Title = "Aim", Icon = "crosshair", Accent = "#38BDF8", Badge = "NEW" })
local Sub    = Main:AddSubTab({ Title = "Alerts", Icon = "bell" })
```

Section, Card e SubTab são containers: todos aceitam `AddButton`, `AddToggle`, etc. Card aceita `Accent` (faixa lateral), `Badge`, `Collapsible` e pode aninhar outro card. Section e Card recolhem com a altura animada.

Badge na aba, pra contador ao vivo (some sozinho quando a janela fica estreita):

```lua
local Main = Window:AddTab({ Title = "Main", Icon = "house", Badge = "3" })
Main:SetBadge(#alvos)
Main:SetBadge(nil)      -- tira
```

---

## Componentes

Campos comuns: `Title`, `Description`, `Icon`, `IconColor`, `TitleColor`, `TitleGradient`, `DescriptionColor`, `EditableTitle`, `EditableDescription`, `Tooltip`, `Badge`, `Cooldown`, `Locked`, `Visible`, `Enabled`.

Métodos comuns: `GetValue` `SetValue` `OnChanged` `SetCallback` `SetTitle` `SetDescription` `SetTitleColor` `SetTitleGradient` `SetTextColor` `SetBadge` `SetIcon` `SetIconColor` `SetEditable` `Edit` `Lock` `Unlock` `IsLocked` `SetCooldown` `SetVisible` `SetEnabled` `SetTooltip` `Flash` `Destroy`.

```lua
Section:AddButton({ Title = "Executar", Cooldown = 5, Callback = function() end })
Section:AddToggle("fly", { Title = "Fly", Default = false, Color = "#4ADE80" })
Section:AddSlider("fov", { Title = "FOV", Min = 10, Max = 400, Default = 120, Increment = 5, Suffix = "px" })
Section:AddInput("key", { Title = "Key", Placeholder = "...", MaxLength = 32, Live = true })
Section:AddKeybind("panic", { Title = "Panic", Default = Enum.KeyCode.P, Mode = "Toggle" })
Section:AddColorpicker("cor", { Title = "Cor", Default = Color3.new(1,0,0), Rainbow = false })
Section:AddSegmented("modo", { Title = "Modo", Values = { "Legit", "Semi", "Rage" } })
Section:AddProgress("load", { Title = "Progresso", Default = 0.35 })
Section:AddCountdown("timer", { Title = "Tempo", Seconds = 30 })
Section:AddStat("kills", { Title = "Kills", Trend = true, Short = true })
Section:AddPlayer("alvo", { Title = "Alvo" })
Section:AddList("whitelist", { Title = "Whitelist", Default = { "ServerDead" } })
Section:AddCode({ Title = "Loadstring", Default = 'loadstring(...)()' })
Section:AddImage({ Image = "https://.../banner.png", Title = "Banner", Height = 120 })
Section:AddPreview({ Title = "ESP preview" })
Section:AddParagraph({ Title = "Nota", Content = "texto <b>com markup</b>" })
Section:AddLabel({ Title = "Só um rótulo" })
Section:AddDivider({ Title = "danger" })
```

### Texto editável

`EditableTitle = true` faz aparecer um lápis no hover; clicar nele ou dar duplo clique no texto abre a edição ali mesmo. Enter confirma, Esc cancela.

### Toggle com cor embutida

O padrão de hub: a linha tem o toggle e, colado nele, o seletor de cor daquela função.

```lua
Section:AddToggle("espbox", {
    Title = "Box",
    Picker = Color3.fromRGB(255, 45, 64),
})

Section:AddToggle("espname", {
    Title = "Nome",
    Picker = { Default = Color3.fromRGB(80, 220, 255), Transparency = 0, Rainbow = true },
})

box.Picker:GetHex()          -- o colorpicker inteiro, com rainbow, swatches e harmonias
box.Picker:SetRainbow(true)
```

O id do picker vira `<id>/Picker`, então ele entra no config e é salvo junto.

---

## Dropdown editável

```lua
local profile = Section:AddDropdown("profile", {
    Title = "Profile",
    Values = { "Default", "Legit", "Rage" },
    Default = "Default",
    Editable = true,    -- renomear opção no lugar
    Creatable = true,   -- linha "+ Add option"
    Removable = true,   -- lixeira por opção
    Searchable = true,  -- filtro (automático acima de 8 opções)
    Icons  = { Default = "user", Legit = "shield", Rage = "flame" },
    Colors = { Rage = "#FF2D40", Legit = "#4ADE80" },
    OnRename = function(antigo, novo) end,
})

profile:AddValue("Silent", { Icon = "eye-off", Color = "#38BDF8" })
profile:RenameValue("Rage", "Ragebot")
profile:RemoveValue("Legit")
```

A lista acompanha o botão quando a página rola e fecha sozinha se o botão sai da área visível. Renomear migra a seleção, os ícones e as cores. `Multi = true` liga seleção múltipla (`SelectAll` / `SelectNone`).

---

## Preview 3D / ESP

Card com o modelo 3D do jogador de um lado e os controles do outro — os toggles aplicam o ESP no preview e no jogo ao mesmo tempo.

```lua
local Esp = Lab:AddPreview({ Title = "ESP preview", Icon = "scan", Label = "ServerDead" })

for _, feature in { "Box", "Corners", "Name", "Distance", "Health", "Tracer", "Skeleton", "Chams" } do
    Esp:AddToggle({
        Title = feature,
        Callback = function(value)
            Esp:SetFeature(feature, value)   -- preview
            MeuHub.Esp[feature] = value      -- jogo
        end,
    })
end

Esp:SetModel(game.Players.OtherPlayer)   -- ou um Model qualquer
Esp:SetColor("#FF2D40")
Esp:SetThickness(2)
Esp:SetHealth(0.4)
Esp:SetSpin(false)
```

O modelo gira sozinho e pode ser arrastado com o mouse. Sem personagem, usa um boneco interno.

---

## Cooldown e cadeado

Qualquer componente pode ser trancado:

```lua
Section:AddButton({ Title = "Executar", Cooldown = 5 })   -- tranca sozinho após clicar

componente:Lock(10)                 -- 10s com contagem 00:10
componente:Lock(0, "Premium")       -- trancado até liberar, com texto
componente:Unlock()
componente:IsLocked()
componente:GetLockRemaining()
```

Aparece um cadeado com a contagem, uma camada fosca por cima, uma barra de tempo embaixo e um brilho que passa no hover. Clicar enquanto trancado sacode o cadeado.

---

## Progress e countdown

O countdown é um slider sem a bolinha, para contagem regressiva em segundos ou porcentagem.

```lua
local t = Section:AddCountdown("timer", {
    Title = "Tempo",
    Seconds = 30,
    AutoStart = false,
    Gradient = { "#FF2D40", "#FACC15" },
    Loop = false,
    OnFinish = function() end,
})

t:Start(60) t:Pause() t:Resume() t:Reset() t:AddTime(10) t:GetRemaining()

local p = Section:AddProgress("load", { Title = "Progresso", Default = 0 })
p:SetProgress(0.5) p:Increment(0.1) p:Complete() p:SetIndeterminate(true)
```

---

## Colorpicker

```lua
Section:AddColorpicker("cor", {
    Title = "Cor",
    Default = Color3.fromRGB(255, 45, 64),
    Transparency = 0,
    Rainbow = false,
    Swatches = true,   -- cores salvas (persistem no config)
    Harmony = true,    -- complementar, triade, analogas, shade, tint
})
```

Dentro do popup: quadro SV, barra de matiz, alpha, cores salvas (clique para usar, botão direito para apagar, `+` para salvar a atual), harmonias geradas a partir da cor, campos HEX/RGB/HSV, **Rainbow** (cicla a cor e dispara o callback — para ESP/chams animados), Reset e copiar hex.

API: `SetRainbow(bool, speed)` `IsRainbow()` `Save()` `Harmonies()` `GetHex()` `Copy()` `SetValueRGB(cor, alpha)`.

---

## Ícones

```lua
Icon = "house"                            -- catálogo lucide embutido (1559 ícones)
Icon = "iconsax:home"                     -- provider remoto por nome
Icon = "https://.../rocket.svg"           -- SVG remoto, vira vetor desenhado
Icon = "https://.../logo.png"             -- PNG/JPG remoto via getcustomasset
Icon = "rbxassetid://123456"              -- asset direto
Icon = "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48"
Icon = "file:DeaDx/icons/meu.png"         -- arquivo local
```

### Foto como ícone e formato da borda

Foto é ícone de primeira classe: avatar, decal seu, PNG da web. Ela é desenhada **como foto**, não pintada com a cor do tema. Só os conjuntos monocromáticos (catálogo, lucide, iconsax) levam a cor do tema, que é o que se quer deles.

```lua
local HEAD = "rbxthumb://type=AvatarHeadShot&id=" .. me.UserId .. "&w=150&h=150"

Section:AddButton({ Title = "Quadrado", Icon = HEAD, IconShape = "Square" })
Section:AddButton({ Title = "Arredondado", Icon = HEAD, IconShape = "Rounded" })
Section:AddButton({ Title = "Círculo", Icon = HEAD, IconShape = "Circle", IconSize = 34 })
Section:AddButton({ Title = "Raio exato", Icon = HEAD, IconCorner = 4 })

Section:AddButton({ Title = "Ícone do catálogo num círculo", Icon = "rocket", IconShape = "Circle" })
```

| Campo | Valores | O que faz |
| --- | --- | --- |
| `IconShape` | `"Square"` `"Rounded"` `"Circle"` | canto reto, canto arredondado ou círculo. Padrão `Square`. |
| `IconCorner` | número ou `"Full"` | raio exato em pixels; passa por cima do `IconShape`. |
| `IconTint` | `true` / `false` | força a cor do tema ligada ou desligada. |
| `IconScale` | `"Fit"` `"Crop"` `"Stretch"` | como a imagem preenche. `Rounded` e `Circle` usam `Crop` sozinhos. |
| `IconSize` | número | lado do ícone; a linha abre espaço, então um avatar de 34px não encosta no título. |

Vale em todo lugar que aceita ícone: janela, tab, section, card, componente, status bar, notificação, diálogo e loading. Em runtime: `componente:SetIconShape("Circle")`, `:SetIconTint(false)`, `Window:SetIconShape(...)`, `Tab:SetIconShape(...)`.

Registrando com nome:

```lua
DeaDx:RegisterIcon("marca", { Source = "https://.../logo.png", Shape = "Circle", Tint = false })
Window:AddTab({ Title = "Hub", Icon = "marca" })
```

**Se uma foto de URL não aparecer**, agora a lib avisa no console o motivo em vez de cair calada no ícone de interrogação. Roblox só desenha **PNG e JPG**, e alguns sites recusam requisição do Roblox (a Wikipédia responde HTML). GitHub raw, Imgur e a maioria dos CDNs funcionam; decal do Roblox por `rbxassetid://` sempre funciona e nem baixa nada.

**Cache em disco:** toda imagem externa é salva **pelo nome** em `DeaDx/icons/<nome>.png` (ou `.svg` + `.json` para vetor), com `index.json` guardando url, hash e tamanho. Na próxima execução vem do disco em ~1ms. Em segundo plano a lib rebaixa uma vez por sessão e compara o hash: **se o conteúdo mudou, sobrescreve e os ícones vivos se atualizam sozinhos**.

```lua
DeaDx:SetIconVerify(false)                                      -- só cache, sem revalidar
DeaDx:SetIconProvider("iconsax")
DeaDx:SetIconTemplate("iconsax", "https://meucdn/%s.svg")
DeaDx:RegisterIcon("logo", "https://.../logo.png")
DeaDx:GetIconStats() DeaDx:ClearIconCache() DeaDx:ForgetIcon("rocket")
```

SVG baixado é parseado (path, line, circle, ellipse, rect, polyline, polygon, com bézier e arco achatados) e desenhado como vetor — aceita cor do tema, gradiente e qualquer tamanho sem perder nitidez.

---

## Cores de texto (markup)

```lua
"<red>perigo</red>  <#FF2D40>hex</#FF2D40>  <color:#38BDF8>outra forma</color>"
"<gradient:#FF2D40:#FACC15>degradê por letra</gradient>  <rainbow>arco-íris</rainbow>"
"<b>negrito</b> <i>itálico</i> <u>sublinhado</u> <s>riscado</s>"
"<size:18>maior</size> <fade:0.4>apagado</fade>  linha 1<br>linha 2"
```

Qualquer campo de cor aceita `Color3`, `"#RRGGBB"`, token do tema (`"Accent"`) ou lista de paradas para virar gradiente.

---

## Status bar

```lua
local Status = DeaDx:CreateStatusBar({
    Title = "<gradient:#FF2D40:#FFFFFF>DeaDx</gradient>",
    Icon = "activity",
    Position = "TopCenter",
    Fps = true, Ping = true, Players = true, Session = true,
    Memory = false, Clock = false, Place = false,
    Draggable = true,
})

Status:AddField("kills", { Label = "Kills", Icon = "sword", Value = function() return kills end })
Status:SetPosition("AboveHotbar")
```

Posições: `TopLeft` `TopCenter` `TopRight` `MiddleLeft` `MiddleRight` `BottomLeft` `BottomCenter` `BottomRight` `Center` `AboveHotbar` `UnderTopbar`, ou um `UDim2` + `Offset`.

---

## Notificações e diálogos

```lua
DeaDx:Notify({ Title = "Pronto", Content = "Tudo certo.", Type = "Success", Duration = 5 })

local r = DeaDx:Ask({ Title = "Confirmar", Content = "Ativar o aimbot?", Options = { "Sim", "Nao" } })
r:OnAnswer(function(v) print(v) end)
local escolha = r:Wait()

local p = DeaDx:Prompt({ Title = "Nome", Input = "digite aqui" })
local texto = p:Wait()
```

Empilham até 6, cada uma compacta com barra de destaque e progresso. `toast:Update{...}` muda o conteúdo ao vivo, `toast:SetProgress(a)` controla a barra.

---

## Key system

A chave é definida pelo dono. Pode ser chave fixa, hash, lista remota, validação por site, ou whitelist por grupo / gamepass / camisa / camisa equipada / nick.

```lua
local key = DeaDx:CreateKeySystem({
    Title = "DeaDx",
    Note = "Entre no grupo ou pegue a chave no #chaves.",
    Salt = "ServerDead",

    -- por chave
    Hashes = { DeaDx:Hash("MINHA-CHAVE", "ServerDead") },   -- a chave NÃO fica no script
    Keys = { "CHAVE-TESTE" },                                -- ou texto puro (fraco)
    Url = "https://.../keys.txt",                            -- lista remota, uma por linha
    Endpoint = "https://api.com/check?key={key}&hwid={hwid}&user={user}",
    Expect = "VALID",                                        -- texto esperado na resposta
    Validate = function(key, hwid) return false end,

    -- por whitelist
    Group = 1069605852, GroupRank = 0,
    Gamepass = { 123456 },
    Asset = { 987654 },        -- precisa ter o item
    Wearing = { 987654 },      -- precisa estar equipado
    Whitelist = { "ServerDead", 123456789 },
    WhitelistUrl = "https://.../nicks.txt",
    Premium = false,
    Checks = { { Label = "Meu requisito", Icon = "star", Run = function() return true end } },

    Require = "any",           -- "any" = qualquer requisito libera; "all" = todos + chave

    Attempts = 3, Lockout = 30,
    Remember = true, ExpiresIn = 86400,
    Integrity = true, BlockOnTamper = false,
    Link = "https://discord.gg/...",
    OnSuccess = function() end, OnFail = function() end, OnTamper = function(f) end,
})

if not key:Wait() then return end
```

Os requisitos viram uma lista com ✓/✗ e o motivo da falha; clicar numa linha revalida. A chave salva vai em `DeaDx/key.dat` como hash, **amarrada ao HWID** (XOR com o HWID + token derivado), então copiar o arquivo para outro PC não funciona. Nunca é o texto da chave que fica salvo.

### Luarmor

Se você já usa Luarmor, o DeaDx checa a chave **antes** do loadstring protegido, então quem errar a chave vê a mensagem na janela em vez de levar kick.

```lua
local key = DeaDx:CreateKeySystem({
    Title = "DeaDx",
    Subtitle = "Luarmor protected",
    Note = "Grab your key in the Discord. It locks to your HWID on first use.",
    Luarmor = {
        ScriptId = "f42f3746fb3eb60f837d3673581c14a6",   -- o id do seu projeto
        Load = true,                                      -- chama api.load_script() ao validar
    },
    Link = "https://discord.gg/seuserver",
    Remember = true,
    Attempts = 3,
    OnSuccess = function(_, info)
        print(info.Executions, info.Note, info.SecondsLeft)
    end,
})
key:Wait()
```

`Luarmor = "f42f..."` também vale, se você só quer o id.

O que ele faz por você:

- baixa a `library.lua` oficial uma vez e reaproveita;
- define o global `script_key` antes de qualquer loadstring, como a doc pede;
- traduz os códigos pra mensagem na janela — `KEY_EXPIRED`, `KEY_BANNED`, `KEY_HWID_LOCKED`, `KEY_INCORRECT`, `KEY_INVALID`, `INVALID_EXECUTOR`, `TIME_ERROR`, `UNKNOWN_ERROR`;
- **só gasta tentativa quando a culpa é do usuário**. Chave errada ou mal formatada consome; `SCRIPT_ID_INCORRECT`, `SCRIPT_ID_INVALID`, servidor fora do ar ou relógio torto não consomem, e os dois primeiros ainda avisam você no console;
- com `Remember = true`, revalida a chave salva no Luarmor ao abrir (não confia só no arquivo local);
- junta com whitelist se quiser: `Group`, `Gamepass`, `Wearing` e companhia continuam valendo junto.

Depois de validar, `key:GetInfo()` devolve o que o Luarmor mandou:

```lua
local info = key:GetInfo()
-- { Expire, Lifetime, SecondsLeft, Note, Executions, FromAd }
key:GetStatus()     -- a tabela crua da API
key:LoadScript()    -- roda api.load_script() na mão
key:PurgeCache()    -- limpa o cache do script protegido
```

Sem a janela, direto:

```lua
local status = DeaDx:Luarmor({ ScriptId = "f42f..." }, minhaChave)
if status.code == "KEY_VALID" then
    DeaDx:LuarmorLoad({ ScriptId = "f42f..." }, minhaChave)
end
```

Vale lembrar: o Luarmor resolve a parte de distribuir e revogar chave, mas o script protegido continua chegando na máquina do usuário. A checagem adiantada é pra experiência, não vira blindagem extra.

---

### O que o key system clássico aguenta (medido)

Testado no próprio executor, contra a lib rodando:

| Ataque | Resultado |
| --- | --- |
| `key:Destroy()` pra matar a UI | **não passa** — `Wait()` volta false |
| `key._valid = true` | **não passa** — não existe esse campo, a validade fica num cofre fora da instância |
| `key:_Accept()` | **não passa** — o método não é público |
| chave errada | **não passa** |
| `hookfunction` em `IsValid` / `Submit` / `Hash.Hmac` | passa, mas o guard **detecta** em até `GuardInterval` e dispara `OnTamper` |
| `getgc` achando o cofre e forjando o selo | **passa**, sem detecção |
| hookar o próprio `isfunctionhooked` | **passa**, mata a detecção |

Ou seja: é um portão honesto contra quem só cola script, e uma lombada contra quem sabe mexer. Não é, e não tem como ser, à prova de quem controla o executor — **o hub já está na máquina dele**. O que fecha isso de verdade é o Key+, onde não existe booleano pra virar porque o código não está lá.

```lua
DeaDx:CreateKeySystem({
    Integrity = true,          -- liga a varredura anti-hook
    GuardInterval = 6,
    BlockOnTamper = true,      -- recusa liberar se achar hook
    OnTamper = function(falhas) DeaDx:Unload() end,
})
```

---

## Key+

No Key+ não existe `return true` pra hookar: **o que o servidor devolve é o próprio hub, criptografado**. Se a validação for burlada, não tem nada pra rodar, porque o código não está no cliente.

**A secret nunca vai pro cliente.** A chave que decifra é derivada da própria chave que o usuário digitou, então o script que você publica não guarda nenhum segredo:

1. O cliente gera um `nonce` aleatório e manda `key`, `hwid` e `nonce` pro seu site.
2. O servidor valida a chave do jeito que quiser (banco, painel, Discord) — é aí que a sua `SECRET` é usada, **só no servidor**.
3. O servidor responde com `ts`, `nonce` e `data`, onde
   `data = hex( XOR(script, keystream(HMAC-SHA256(key_do_usuario, "ukey|nonce|ts"))) )`
4. O cliente confere o `ts` (vale 5 min) e o `nonce`, deriva a mesma chave com a chave digitada e **decifra o hub**. Se a chave estiver errada, sai lixo e nada roda.

```lua
local key = DeaDx:CreateKeySystem({
    Title = "DeaDx",
    Plus = {
        Endpoint = "https://meusite.com/api/unlock",   -- {key} {hwid} {nonce} são preenchidos
        Window = 300,                                   -- validade da resposta, em segundos
    },
    Remember = true,
    OnUnlock = function(source)
        loadstring(source)()      -- aqui roda o hub de verdade
    end,
})
key:Wait()
```

Se você quiser **também** assinar a resposta (uma camada a mais contra endpoint falso), aí sim passe uma `Secret` no cliente — ela entra na assinatura e na derivação. É opcional e vale só se você aceitar que esse valor fique no script:

```lua
Plus = { Endpoint = "...", Secret = "CodigoDecode" }   -- modo com assinatura
```

Também dá pra usar sem a UI:

```lua
local source, reason = DeaDx:KeyPlus({ Endpoint = "...", Secret = "..." }, "CHAVE-DO-USUARIO")
if not source then return warn(reason) end
loadstring(source)()

-- ou direto
DeaDx:KeyPlusRun({ Endpoint = "...", Secret = "..." }, "CHAVE-DO-USUARIO")
```

Recusa automática: secret errada, chave errada, assinatura forjada, nonce trocado e resposta velha (replay) — todas caem antes de decifrar qualquer coisa.

Forçar a validação não adianta: virar o estado interno deixa a janela fechar e `GetPayload()` continua `nil`, `RunPayload()` devolve "missing payload" e `OnUnlock` nunca dispara. Sem resposta legítima do servidor não existe hub pra rodar.

**O que o Key+ ainda não resolve**, pra você saber onde está pisando:

- quem tem uma chave válida recebe o hub em texto na memória e pode despejar ele. Key+ impede acesso **sem chave**, não impede vazamento por quem pagou. Pra isso, marque o payload por chave no servidor e você descobre de quem vazou.
- se o seu endpoint não tiver limite de tentativa, dá pra forçar chave na força bruta do lado do servidor.
- com `Remember = true`, a chave fica no disco embaralhada com o HWID. Protege contra copiar o arquivo pra outra máquina, não contra quem já está na mesma máquina.
- o payload só vale o que tem dentro: se o hub também estiver embutido no script que chama o Key+, não adiantou nada.

### O que o seu servidor precisa fazer

```
GET /api/unlock?key=<key>&hwid=<hwid>&nonce=<nonce>&v=1

1. valida <key> no seu banco (sua SECRET entra aqui e NUNCA sai do servidor)
2. ts    = tempo unix agora
3. skey  = HMAC_SHA256(key, "ukey|" + nonce + "|" + ts)
4. ks    = SHA256(skey + ":0") .. SHA256(skey + ":1") .. ...   (bytes crus, até o tamanho do script)
5. data  = hex(script XOR ks)
6. responde {"v":1,"ts":ts,"nonce":nonce,"data":data}

Em erro: {"error":"chave invalida"}
```

No modo com assinatura, troque `key` por `SECRET` no passo 3 (tag `stream` em vez de `ukey`) e some
`sig = HMAC_SHA256(SECRET, "v1|" + key + "|" + hwid + "|" + nonce + "|" + ts)` na resposta.

`sig` em hex minúsculo. `data` aceita hex ou base64. O script pode começar com `--DEADX` para o cliente reconhecer o conteúdo sem compilar. Com `BindHwid = true` o `hwid` também entra na derivação.

Para testar sem servidor, a lib monta a resposta igualzinha:

```lua
local cfg = { Endpoint = "https://x" }
local resposta = DeaDx:KeyPlusPack(cfg, "CHAVE", DeaDx:GetHwid(), nil, os.time(), "--DEADX\nprint('ok')")
local fonte, motivo = DeaDx:KeyPlusOpen(cfg, "CHAVE", DeaDx:GetHwid(), resposta.nonce, resposta)
```

---

## Loading screen

```lua
local loader = DeaDx:CreateLoadingScreen({
    Title = "DeaDx",
    Subtitle = "preparando o hub",
    Icon = "zap",
    TitleGradient = { "#FF2D40", "#FFFFFF" },
    Gradient = { "#FF2D40", "#FACC15" },
    Steps = { "Verificando ambiente", "Carregando icones", "Montando interface" },
    Tips = { "Segure a barra do topo para arrastar" },
    Footer = "by ServerDead",
    MinDuration = 0,     -- tempo mínimo na tela
})

loader:Run({                       -- roda cada passo de verdade e fecha no fim
    function() checarAmbiente() end,
    function() carregarIcones() end,
    function() montarUI() end,
})

-- ou manual
loader:SetProgress(0.5, "metade")
loader:Step("proximo")
loader:Finish("Pronto")
```

---

## Dependências entre componentes

Um controle só aparece (ou só liga) quando outro está do jeito certo. Sem `if` espalhado pelo hub:

```lua
Section:AddToggle("aimbot", { Title = "Aimbot" })
Section:AddSlider("fov", { Title = "FOV", Min = 1, Max = 400, VisibleWhen = "aimbot" })
Section:AddSegmented("modo", { Title = "Modo", Values = { "Legit", "Rage" } })
Section:AddToggle("silent", { Title = "Silent aim", VisibleWhen = { modo = "Rage" } })
Section:AddSlider("hitchance", { Title = "Hit chance", Min = 0, Max = 100, EnabledWhen = { aimbot = true, modo = { "Rage", "Semi" } } })
Section:AddToggle("x", { Title = "X", VisibleWhen = function(opts) return opts.fov:GetValue() > 100 end })
```

`VisibleWhen` / `EnabledWhen` aceitam o id de outra opção, uma tabela `{ id = valor }` (valor pode ser uma lista de aceitos ou uma função) ou uma função. Reage sozinho a qualquer mudança no config.

---

## Menu de contexto

Clique direito em qualquer componente:

- **Copiar valor** — manda o valor atual pra área de transferência
- **Voltar ao padrão** — volta pro `Default`
- **Definir tecla** — captura uma tecla que passa a alternar/executar aquele componente
- **Fixar na status bar** — o valor vira um campo ao vivo na barra; se for toggle ou botão o campo fica **clicável**, então dá pra virar a função sem abrir a janela. Fixar de novo tira.

```lua
Section:AddToggle("fly", {
    Title = "Fly",
    Key = Enum.KeyCode.F,          -- já nasce com tecla
    Menu = {                        -- entradas suas no menu
        { Title = "Resetar posicao", Icon = "map-pin", Callback = function() end },
    },
})
```

`Menu = false` desliga o menu naquele componente.

---

## Command palette

`Ctrl+K` abre uma busca por cima de tudo: acha qualquer componente de qualquer aba, mostra o caminho e o valor atual, e **usa** direto — toggle alterna, botão executa, o resto navega até ele.

```lua
local palette = Window:GetPalette()
palette:AddAction({ Title = "Recarregar hub", Icon = "rotate-ccw", Detail = "acao do dev", Callback = function() end })
palette:SetKey(Enum.KeyCode.K, Enum.KeyCode.LeftControl)
palette:Open()
```

Setas navegam, enter usa, esc fecha. Busca é fuzzy (`recar` acha `Recarregar hub`). Desligue com `Palette = false` na janela.

---

## Desfazer e refazer

Toda mudança de componente com `id` entra num histórico de 120 passos. **Não vem com tecla nenhuma** — você liga se quiser:

```lua
DeaDx:Undo() DeaDx:Redo() DeaDx:CanUndo() DeaDx:CanRedo()
DeaDx.Config:ClearHistory()

Window:SetUndoKeys(Enum.KeyCode.Z, Enum.KeyCode.Y)   -- opcional, pede o modificador junto
```

Dá pra expor pela palette sem tecla nenhuma:

```lua
Window:GetPalette():AddAction({ Title = "Desfazer", Icon = "undo-2", Callback = function() DeaDx:Undo() end })
```

---

## Tour guiado

Apresenta o hub pra quem abriu pela primeira vez: escurece tudo, acende só o componente da vez e explica ao lado. Troca de aba e rola a página sozinho até achar o alvo.

```lua
Window:Tour({
    { Target = "aimbot", Title = "Aimbot", Text = "Liga a mira. Clique direito pra definir uma tecla." },
    { Target = "fov",    Title = "FOV",    Text = "Raio do circulo." },
    { Tab = "Visual", Target = "theme", Title = "Tema", Text = "Troque as cores aqui." },
    { Target = someFrame, Title = "Livre", Text = "Tambem aceita um GuiObject direto." },
}, {
    Color = "#FF2D40",
    OnFinish = function(pulou) end,
})
```

Setas e enter navegam, esc pula. Cada passo aceita `Delay` e `Run` (roda algo ao chegar). O tour corrige a posição sozinho depois que a rolagem assenta, então a caixa cai exatamente em cima mesmo com animação no caminho.

---

## Console de logs

```lua
DeaDx:Log("hub carregado", "Success", "boot")
DeaDx:Log("sem permissao de arquivo", "Warning", "fs")
DeaDx:Log("falhou ao achar o remote", "Error", "net")

DeaDx:AddConsole(Section, { Height = 180 })
DeaDx:MirrorLog(true)     -- espelha no print/warn do executor
DeaDx:GetLog()            -- tudo em texto, pra copiar
DeaDx:ClearLog()
```

Níveis `Info` `Success` `Warning` `Error` `Debug`, com hora, tag e cor por nível. O painel tem filtro por texto, filtro por nível, copiar tudo e limpar, e rola sozinho conforme chega.

---

## Painel de configs

```lua
DeaDx:AddConfigManager(Section)
```

Monta tudo de uma vez: nome, lista dos salvos, salvar, carregar, apagar (com cooldown), atualizar lista, salvar sozinho, copiar o json, colar um json pra importar e resetar tudo.

---

## Painel de teclas

```lua
DeaDx:AddKeybinds(Section)
```

Lista toda tecla definida no hub, de keybinds e dos componentes que ganharam tecla pelo menu de contexto. Clicar numa linha regrava, botão direito limpa.

---

## Gráfico ao vivo

```lua
Section:AddGraph({
    Title = "FPS",
    Icon = "activity",
    Source = function() return workspace:GetRealPhysicsFPS() end,
    Interval = 0.25,
    Capacity = 90,
    Gradient = { "#FF2D40", "#FACC15" },
})
```

Também dá pra alimentar na mão com `grafico:Push(valor)`. Métodos: `Latest` `Average` `Bounds` `Clear` `Bind` `Unbind`.

---

## Temas

`DeaDx` `Dark` `Darker` `Amoled` `Light` `Midnight` `Crimson` `Ocean` `Forest` `Amethyst` `Sunset`

```lua
DeaDx:SetTheme("Midnight")
DeaDx:SetAccent("#38BDF8")
DeaDx:RegisterTheme("Meu", { Base = "Dark", Accent = Color3.fromRGB(255,45,64) })
DeaDx:SetTheme({ Name = "Inline", Base = "Dark", Accent = Color3.new(1,0,0) })  -- tema na hora
DeaDx:LockTheme("DeaDx")   -- prende o tema
DeaDx:LockScale(1)         -- prende a escala
```

Tokens: `Background` `SecondaryBackground` `TertiaryBackground` `Text` `MutedText` `Accent` `AccentText` `Border` `Hover` `Pressed` `Success` `Warning` `Error` `Info` `Overlay` `AcrylicTint` `AcrylicGradient` `AcrylicNoise` `AcrylicTransparency` `ElementTransparency` `ComponentTransparency` `ComponentStrokeTransparency`.

### Editor de tema pronto

Uma linha monta uma aba inteira com colorpicker pra cada token, sliders de transparência, copiar a tabela e salvar como tema novo:

```lua
local Tema = Window:AddTab({ Title = "Tema", Icon = "palette" })
DeaDx:AddThemeEditor(Tema, { Name = "MeuTema" })

local fonte = DeaDx:ExportTheme("MeuTema")   -- a tabela Lua pronta, em string
```

---

## Animações

Tudo passa pelo `Animation` com easings nomeados: `Smooth` (Quint), `Soft` (Sine), `Snap` (Back), `Glide` (Cubic InOut).

```lua
DeaDx.Component  -- ...
local Animation = ... -- via import nos seus componentes
Animation:Play(obj, { Size = ... }, { Duration = 0.26, Ease = "Smooth" })
Animation:Snap(obj, { Scale = 1 })
Animation:Sequence(lista, function(item, index, delay) ... end)
Animation.Enabled = false   -- desliga tudo (acessibilidade / fps baixo)
```

Detalhes que entraram sem aparecer no caminho: componentes entram escalonados quando a aba abre, uma barrinha de destaque desliza na lateral no hover, o popup abre com escala e desliza do lugar certo, section e card recolhem com altura animada em vez de sumir, troca de cor de ícone é interpolada, a janela abre com um leve pop, o knob do toggle dá uma esticada, o knob do slider cresce enquanto arrasta, o chevron do dropdown gira, e o keybind pulsa com brilho na borda quando a tecla muda.

---

## Config

Todo componente com `id` entra no config e é salvo/carregado junto.

```lua
DeaDx:Save("meuconfig") DeaDx:Load("meuconfig") DeaDx:ListConfigs()
DeaDx:DeleteConfig("x") DeaDx:SetAutoSave(true) DeaDx:ResetConfig()
```

Arquivos em `DeaDx/configs/<nome>.json`. `Color3`, `EnumItem` e `Vector2` voltam no tipo certo.

---

## Anti-hook

```lua
local relatorio = DeaDx:Integrity()
-- { Clean = true, Failures = {}, Detection = { IsFunctionHooked = true, ... } }

DeaDx:GuardIntegrity(6, function(failures)
    DeaDx:Notify({ Title = "Ambiente alterado", Content = failures[1], Type = "Error" })
end)
```

Usa `isfunctionhooked`, `iscclosure`, `islclosure`, `getrawmetatable` e `checkcaller` quando o executor oferece. Confere `game.HttpGet`, `GetService`, `JSONDecode/Encode`, `UserOwnsGamePassAsync`, `PlayerOwnsAsset`, `IsInGroup`, `GetRankInGroup`, `string.*`, `table.concat`, `bit32.bxor`, `os.time` e os metamétodos `__namecall` / `__index` do `game`. O que não existe no executor é ignorado em vez de dar erro.

---

## Estrutura

```
src/
  init.luau          carregador (Studio / HTTP)
  Bootstrap.luau     monta a API pública
  Types.luau         tipos Luau
  Core/              Signal State Capabilities Utility Markup Hash Integrity
                     Theme Config Widgets Editable Search Component Section
                     Card Tab Window
  Services/          Cleanup Animation Input Drag Acrylic Tooltip Notification
                     StatusBar Loading KeySystem KeyPlus Luarmor Palette
                     ThemeEditor Tour Console ConfigPanel KeybindPanel
  Icons/             Catalog Svg Store Providers Registry Icon
  Components/        Button Toggle Slider Dropdown MultiDropdown Input Keybind
                     Colorpicker Paragraph Label Divider Notification Dialog
                     Segmented Progress Countdown Stat Image Code List Player
                     Preview Graph
  Themes/            Default DeaDx Dark Darker Amoled Light Midnight Crimson
                     Ocean Forest Amethyst Sunset
build.ps1            gera o DeaDx.lua de arquivo único
example.luau         demo completa
```

```powershell
.\build.ps1
```

Componentes são importados sob demanda e o catálogo de ícones só é parseado no primeiro ícone usado, então a lib sobe em poucos ms (`DeaDx.LoadTime`).

---

Créditos: **ServerDead**.
