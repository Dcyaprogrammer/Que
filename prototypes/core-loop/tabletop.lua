local Rules, Config = require("rules"), require("config")
local Art, Feedback = require("table_art"), require("table_feedback")
local Table = {}
Table.__index = Table
local sin, cos = math.sin(math.rad(25)), math.cos(math.rad(25))
local handWidth, handHeight, handDepth, handZ = 52, 90, 14, -90
local wallWidth, wallLength, wallLayer = 52, 76, 18
local C = { ivory = { .94, .90, .79 }, ink = { .18, .20, .15 },
    brass = { .70, .53, .29 }, gold = { .95, .73, .38 }, muted = { .64, .66, .51 },
    dark = { .045, .065, .05 }, red = { .66, .15, .11 }, green = { .08, .28, .20 } }
local groupNames = { pair = "对子", sequence = "顺子", triplet = "刻子" }
local marks = { { .70,.32,.20 }, { .20,.49,.36 }, { .21,.39,.62 }, { .52,.32,.55 },
    { .65,.51,.18 }, { .21,.51,.51 }, { .48,.46,.35 } }

function Table.project(x, height, depth)
    local d = (600 - height) * sin + (depth + 850) * cos
    return 640 + 1250 * x / d, 340 - 1250 * ((height - 600) * cos + (depth + 850) * sin) / d
end

function Table.bounds(quad)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, 8, 2 do
        minX, maxX = math.min(minX, quad[i]), math.max(maxX, quad[i])
        minY, maxY = math.min(minY, quad[i + 1]), math.max(maxY, quad[i + 1])
    end
    return { x = minX, y = minY, w = maxX - minX, h = maxY - minY, quad = quad }
end

function Table.hit(rect, x, y)
    if not rect.quad then
        return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
    end
    local sign
    for i = 1, 8, 2 do
        local nextI = i % 8 + 2
        local j = nextI == 9 and 1 or nextI
        local cross = (rect.quad[j] - rect.quad[i]) * (y - rect.quad[i + 1])
            - (rect.quad[j + 1] - rect.quad[i + 1]) * (x - rect.quad[i])
        if math.abs(cross) > .001 then
            local current = cross > 0
            if sign ~= nil and current ~= sign then return false end
            sign = current
        end
    end
    return true
end

local function rgba(tint, alpha) love.graphics.setColor(tint[1], tint[2], tint[3], alpha or 1) end
local function heldPose(x,y)
    return {x-36,y-50,x+36,y-50,x+36,y+50,x-36,y+50}
end
local function rectangle(x, y, w, h, tint, radius)
    rgba(tint); love.graphics.rectangle("fill", x, y, w, h, radius or 0, radius or 0)
end

function Table.new(fonts)
    local self = setmetatable({ fonts = fonts, art = Art.new(fonts), feedback = Feedback.new(true),
        poses = {}, offsetX = 0, offsetY = 0, detail = false, archive = false }, Table)
    self.mesh = love.graphics.newMesh({ {0,0,0,0,1,1,1,1}, {1,0,1,0,1,1,1,1},
        {1,1,1,1,1,1,1,1}, {0,1,0,1,1,1,1,1} }, "fan", "dynamic")
    return self
end

function Table:text(value, x, y, size, tint, width, align)
    love.graphics.setFont(self.fonts[size or 20]); rgba(tint or C.ivory)
    if width then love.graphics.printf(tostring(value), x, y, width, align or "left")
    else love.graphics.print(tostring(value), x, y) end
end

function Table:quad(points)
    local result = {}
    for _, point in ipairs(points) do
        local x, y = Table.project(point[1], point[2], point[3])
        result[#result + 1], result[#result + 2] = x + self.offsetX, y + self.offsetY
    end
    return result
end

function Table:flat(x, z, w, length, height)
    height = height or 0
    return self:quad({ {x-w/2,height,z+length/2}, {x+w/2,height,z+length/2},
        {x+w/2,height,z-length/2}, {x-w/2,height,z-length/2} })
end

function Table:surface(quad, tint, texture, alpha)
    rgba(tint or {1,1,1}, alpha)
    if texture then
        self.mesh:setVertices({ {quad[1],quad[2],0,0,1,1,1,1}, {quad[3],quad[4],1,0,1,1,1,1},
            {quad[5],quad[6],1,1,1,1,1,1}, {quad[7],quad[8],0,1,1,1,1,1} })
        self.mesh:setTexture(texture); love.graphics.draw(self.mesh)
    else love.graphics.polygon("fill", quad) end
end

function Table:hotspot(ui, id, rect, enabled, action)
    rect.id, rect.enabled, rect.action = id, enabled, action
    ui.buttons[#ui.buttons + 1] = rect
end

function Table:metalButton(ui, id, label, x, y, w, action, selected)
    rectangle(x, y+4, w, 32, C.dark, 4)
    rectangle(x, y, w, 32, selected and C.brass or { .18,.20,.15 }, 4)
    self:text(label, x, y+6, 14, selected and C.dark or C.ivory, w, "center")
    self:hotspot(ui, id, {x=x,y=y,w=w,h=36}, true, action)
end

function Table:reset()
    self.feedback:reset()
    self.poses, self.drag, self.detail, self.archive = {}, nil, false, false
    self.offsetX, self.offsetY = 0, 0
end

function Table:handPose(index, raise)
    local x = index == 15 and 432 or -351 + (index - 1) * 54
    local h, half = handHeight + (raise or 0), handWidth / 2
    return self:quad({ {x-half,h,handZ}, {x+half,h,handZ},
        {x+half,raise or 0,handZ}, {x-half,raise or 0,handZ} }), x
end

function Table:wallPose(index)
    if index <= 17 then return -432 + (index - 1) * 54, 870, false end
    if index <= 34 then return -432 + (index - 18) * 54, 780, false end
    if index <= 48 then return -470, 680 - (index - 35) * 54, true end
    return 470, 680 - (index - 49) * 54, true
end

function Table:wallTilePose(index, level)
    local x,z,side = self:wallPose(index)
    return self:flat(x,z,side and wallLength or wallWidth,
        side and wallWidth or wallLength,level*wallLayer),side
end

function Table:riverPose(index, count)
    local visible = math.min(24, count)
    local position = index - (count - visible) - 1
    if position < 0 then return nil end
    local col, row = position % 8, math.floor(position / 8)
    return self:flat(-196 + col * 56, 515 - row * 80, wallWidth, wallLength, 11)
end

function Table:drawFlat(tile, quad, back, alpha, side)
    local bottom = {}
    for i = 1, 8, 2 do bottom[i], bottom[i+1] = quad[i], quad[i+1] + 5 end
    self:surface({ quad[7],quad[8],quad[5],quad[6],bottom[5],bottom[6],bottom[7],bottom[8] },
        { .55,.53,.39 }, nil, alpha)
    self:surface(quad, nil, back and (side and self.art.backSide or self.art.back)
        or self.art.faces[tile.kind], alpha)
end

function Table:drawRoom()
    love.graphics.clear(.055,.065,.045)
    for y = 0, 230, 4 do
        local t = y / 230
        love.graphics.setColor(.045+t*.035, .052+t*.045, .035+t*.03)
        love.graphics.rectangle("fill", 0, y, 1280, 4)
    end
    for x = 20, 1280, 110 do rectangle(x, 0, 3, 250, { .095,.095,.06 }) end
    self:surface(self:quad({{-560,0,950},{560,0,950},{560,0,-180},{-560,0,-180}}), nil, self.art.wood)
    self:surface(self:quad({{-560,0,-180},{560,0,-180},{560,-55,-180},{-560,-55,-180}}), { .23,.11,.055 })
    self:surface(self:flat(0,380,1000,1040), nil, self.art.felt)
    rgba({ .41,.40,.21 }); love.graphics.setLineWidth(2)
    love.graphics.polygon("line", self:flat(0,380,980,1020))
    rgba({ .075,.19,.14 }); love.graphics.setLineWidth(2)
    love.graphics.polygon("line", self:flat(0,380,950,990))
    love.graphics.setBlendMode("alpha","premultiplied")
    love.graphics.setColor(.7,.7,.7,.7); love.graphics.draw(self.art.light)
    love.graphics.setBlendMode("alpha")
    self:text("雀", 560+self.offsetX, 365+self.offsetY, 48, { .23,.37,.25 }, 160, "center")
    rectangle(638,0,4,20,{ .10,.10,.07 })
    self:surface({594,12,686,12,720,47,560,47}, { .20,.19,.12 })
    rgba({ .85,.66,.31 }); love.graphics.ellipse("fill",640,47,80,9)
    rgba({ 1,.89,.59 }); love.graphics.ellipse("fill",640,48,60,4)
end

function Table:drawMachine(ui)
    local run = ui.run
    rectangle(377,94,526,122,{ .025,.035,.025 },8)
    rectangle(382,86,516,120,{ .25,.25,.18 },8)
    rectangle(393,95,494,100,{ .075,.09,.065 },4)
    for _, point in ipairs({{389,92},{890,92},{389,197},{890,197}}) do
        rgba(C.brass); love.graphics.circle("fill",point[1],point[2],3)
        rgba(C.dark); love.graphics.line(point[1]-2,point[2],point[1]+2,point[2])
    end
    self:text("累计分数",410,102,14,C.muted)
    local digits = string.format("%05d", math.floor(self.feedback.score))
    for i = 1, #digits do
        local x = 407+(i-1)*40
        rectangle(x,128,36,51,{ .035,.045,.03 },2)
        self:text(digits:sub(i,i),x,135,32,C.gold,36,"center")
        love.graphics.setColor(.3,.3,.2,.3); love.graphics.line(x,153,x+36,153)
    end
    self:text("本关目标",661,104,14,C.muted)
    self:text(Config.target,659,135,32,C.ivory)
    self:text("摸牌 "..run.draws,797,110,16,C.ivory)
    self:text("结算 "..run.settlements,797,151,16,C.ivory)
    rectangle(50,151,203,48,{ .18,.17,.11 },3)
    self:text("QUE 雀  /  "..run.build.name,61,165,20,C.ivory)
    self:text("种子 "..run.seed,64,208,14,C.muted)
end

function Table:drawWall(ui, actions)
    local count = #ui.run.wall
    for stack = 1, math.ceil(count / 2) do
        local levels = math.min(2, count - (stack-1)*2)
        for level = 1, levels do
            local quad,side = self:wallTilePose(stack,level)
            self:drawFlat({kind=1},quad,true,nil,side)
            self:hotspot(ui,"draw",Table.bounds(quad),ui.run.phase=="ready" and ui.run.draws>0,
                actions.draw)
        end
    end
    rectangle(1034,218,176,60,{ .19,.20,.13 },4)
    self:text("牌山  "..count.." 张",1047,226,20,C.ivory)
    self:text("点击摸牌 / 空格",1047,252,14,C.muted)
    self:hotspot(ui,"draw",{x=1034,y=218,w=176,h=60},
        ui.run.phase=="ready" and ui.run.draws>0 and count>0,actions.draw)
end

function Table:drawRiver(ui)
    self.dropRect = Table.bounds(self:flat(0,440,460,280,1))
    if self.drag and self.drag.moved then
        local valid = Table.hit(self.dropRect,self.drag.x,self.drag.y)
        self:surface(self.dropRect.quad,valid and { .36,.43,.24 } or { .19,.33,.23 },nil,.4)
        rgba(valid and C.gold or C.muted); love.graphics.setLineWidth(2)
        love.graphics.polygon("line",self.dropRect.quad)
        self:text(valid and "松手打出" or "拖到桌心打出",480,302,20,C.ivory,320,"center")
    end
    local flying = {}
    for _, flight in ipairs(self.feedback.flights) do flying[flight.tile.id]=true end
    for i = math.max(1,#ui.run.discards-23), #ui.run.discards do
        local tile=ui.run.discards[i]
        if not flying[tile.id] then self:drawFlat(tile,self:riverPose(i,#ui.run.discards)) end
    end
    if #ui.run.discards==0 and not self.drag then
        self:text("打牌区",520,350,20,{ .37,.46,.31 },240,"center")
    end
end

function Table:drawHand(ui)
    local flying = {}
    for _, flight in ipairs(self.feedback.flights) do flying[flight.tile.id]=flight end
    local membership={}
    if ui.displayScore then
        for index,group in ipairs(ui.displayScore.groups) do
            for _,tile in ipairs(group.tiles) do membership[tile.id]=index end
        end
    end
    for index,tile in ipairs(ui.run.hand) do
        local selected=ui.hoverId==tile.id
        local raise=selected and not self.feedback.reduced and 9 or 0
        local pose,x=self:handPose(index,raise)
        local shadow=self:flat(x,handZ+18,handWidth+8,37)
        self:surface(shadow,{0,0,0},nil,.22)
        self.poses[tile.id]=pose
        local visiblePose=flying[tile.id] and Feedback.pose(flying[tile.id]) or pose
        local rect=Table.bounds(visiblePose); rect.index,rect.tileId=index,tile.id
        ui.tileRects[#ui.tileRects+1]=rect
        if not flying[tile.id] and not (self.drag and self.drag.id==tile.id) then
            local h,half,z=handHeight+raise,handWidth/2,handZ
            self:surface(self:quad({{x-half,h,z},{x+half,h,z},
                {x+half,h,z+handDepth},{x-half,h,z+handDepth}}),{.95,.91,.78})
            self:surface(self:quad({{x+half,h,z},{x+half,h,z+handDepth},
                {x+half,raise,z+handDepth},{x+half,raise,z}}),{.59,.64,.47})
            self:surface(pose,nil,self.art.faces[tile.kind])
            if membership[tile.id] then
                local m=membership[tile.id]
                rgba(marks[m]); love.graphics.setLineWidth(3)
                love.graphics.line(pose[7]+7,pose[8]-3,pose[5]-7,pose[6]-3)
            end
            if Rules.value(tile,ui.run.build,Config)>Config.tileBase then
                rgba(C.brass); love.graphics.setLineWidth(2); love.graphics.polygon("line",pose)
            end
            if selected then
                rgba(C.gold); love.graphics.setLineWidth(2); love.graphics.polygon("line",pose)
            end
        end
        if tile.id==ui.run.drawnId then
            self:text("新摸",rect.x,rect.y-24,16,C.gold,rect.w,"center")
        end
    end
end

function Table:paper(x,y,w,h)
    rectangle(x+5,y+7,w,h,{ .08,.10,.065 },3)
    rectangle(x,y,w,h,{ .85,.80,.65 },2)
    rectangle(x+4,y+2,w-8,h-5,C.ivory,1)
    rgba({ .68,.63,.48 }); love.graphics.setLineWidth(1)
    for line=y+46,y+h-10,27 do love.graphics.line(x+13,line,x+w-13,line) end
end

function Table:drawReceipt(ui)
    local score=ui.displayScore
    self:paper(48,275,258,195)
    self:text("记分单",65,287,20,C.ink)
    if score then
        self:text(score.total,65,319,48,C.red)
        self:text("("..score.base.." + "..score.bonus.." + "..score.item..") × "..score.multiplier,
            65,379,16,C.ink)
        self:text(score.winning and table.concat(score.yaku," / ") or
            (score.complete and "成型无役 · 普通计分" or "普通手牌也能结算"),65,409,14,C.ink,221)
    else
        self:text("先打出一张牌",65,330,24,C.ink)
        self:text("悬停看弃牌后得分",65,380,16,C.ink)
    end
    self:text("点击展开明细",65,443,14,{ .46,.40,.26 })
    self:hotspot(ui,"details",{x=48,y=275,w=258,h=195},true,function() self.detail=true end)
    rectangle(912,411,290,49,{ .28,.24,.14 },3)
    self:text("弃牌记录  "..#ui.run.discards.." 张",925,418,20,C.ivory)
    self:text("点击翻看全部",925,443,14,C.muted)
    self:hotspot(ui,"archive",{x=912,y=411,w=290,h=49},true,function() self.archive=true end)
end

function Table:drawControls(ui,actions)
    local run=ui.run
    local active=run.phase=="ready" or run.phase=="discard"
    self:metalButton(ui,"menu","返回选桌",1133,15,100,actions.menu)
    self:metalButton(ui,"sound",self.feedback.muted and "声音 关 [M]" or "声音 开 [M]",49,787,134,
        function() self.feedback:mute() end)
    self:metalButton(ui,"motion",self.feedback.reduced and "动效 少 [V]" or "动效 开 [V]",195,787,134,
        function() self.feedback:reduce() end)
    if active then
        rgba({.045,.055,.035}); love.graphics.ellipse("fill",1119,743,66,34)
        rgba(C.brass); love.graphics.ellipse("fill",1119,733,61,33)
        rgba({.31,.08,.06}); love.graphics.ellipse("fill",1119,731,48,26)
        rgba(run.phase=="ready" and C.red or {.27,.18,.12}); love.graphics.ellipse("fill",1119,721,48,26)
        self:text("结算",1070,707,24,C.ivory,98,"center")
        self:text("回车",1070,758,14,C.muted,98,"center")
        self:hotspot(ui,"settle",{x=1060,y=690,w=118,h=75},run.phase=="ready",actions.settle)
        local message=run.phase=="discard" and "点击手牌打出，或拖到桌心；拖回桌外可取消。"
            or "点击牌山摸牌；按结算按钮提交整手牌。"
        self:text(message,110,692,20,C.ivory,870,"center")
        local tile=ui.hoverIndex and run.hand[ui.hoverIndex]
        if tile then
            self:text(Rules.label(tile.kind).."  /  "..Rules.value(tile,run.build,Config).." 分",
                370,746,20,C.gold,490,"center")
        elseif ui.notice then self:text(ui.notice,370,746,20,C.gold,490,"center") end
    else
        rectangle(325,325,630,135,{ .10,.14,.095 },7)
        self:text(run.phase=="won" and "本关达成" or "本关结束",350,340,48,
            run.phase=="won" and C.gold or C.ivory,580,"center")
        self:text(run.reason,350,409,20,C.muted,580,"center")
        self:metalButton(ui,"retry","同配置再试 [R]",370,692,240,actions.retry,true)
        self:metalButton(ui,"nextseed","下一个种子",635,692,240,actions.nextseed)
    end
end

function Table:drawOverlays(ui,actions)
    if not self.detail and not self.archive then return end
    love.graphics.setColor(0,0,0,.35); love.graphics.rectangle("fill",0,0,1280,840)
    ui.buttons,ui.tileRects={},{}
    self:metalButton(ui,"menu","返回选桌",1133,15,100,actions.menu)
    if self.detail then
        self:paper(55,220,515,540)
        self:text("本手计分明细",80,240,24,C.ink)
        local score=ui.displayScore
        if score then
            self:text(score.total.." 分",80,283,32,C.red)
            self:text("单牌 "..score.base.." + 组合 "..score.bonus.." + 道具 "..score.item,
                80,335,20,C.ink)
            self:text("倍率 ×"..score.multiplier.."  "..table.concat(score.yaku," / "),80,369,16,C.ink,460)
            for i,group in ipairs(score.groups) do
                local names={}
                for _,tile in ipairs(group.tiles) do names[#names+1]=Rules.label(tile.kind) end
                self:text(table.concat(names," ").."  "..groupNames[group.kind].." +"..group.bonus
                    ..(group.item>0 and (" / 道具 +"..group.item) or ""),80,418+(i-1)*34,16,marks[i],460)
            end
        else self:text("先完成弃牌，再查看本手得分。",80,320,20,C.ink) end
        self:metalButton(ui,"closeDetails","收起记分单 [Esc]",80,702,270,function() self.detail=false end,true)
    else
        self:paper(823,230,410,454)
        self:text("弃牌记录  /  "..#ui.run.discards.." 张",844,247,24,C.ink)
        local width,height=love.graphics.getDimensions()
        local scale=math.min(width/1280,height/840)
        ui.maxScroll=math.max(0,math.ceil(#ui.run.discards/10)*38-260)
        ui.discardScroll=math.max(0,math.min(ui.maxScroll,ui.discardScroll))
        love.graphics.setScissor((width-1280*scale)/2+840*scale,
            (height-840*scale)/2+300*scale,366*scale,260*scale)
        for i,tile in ipairs(ui.run.discards) do
            local x,y=844+(i-1)%10*36,300+math.floor((i-1)/10)*38-ui.discardScroll
            self:drawFlat(tile,{x,y,x+31,y,x+31,y+34,x,y+34})
        end
        love.graphics.setScissor()
        self:text("滚轮翻看 · 本关不回洗",844,582,16,C.ink)
        self:metalButton(ui,"closeArchive","合上记录本 [Esc]",844,628,270,function() self.archive=false end,true)
    end
end

function Table:draw(ui,actions)
    local run=ui.run
    ui.displayScore=run.preview
    if run.phase=="discard" then ui.displayScore=ui.hoverScore end
    if run.phase=="won" or run.phase=="lost" then ui.displayScore=run.lastResult end
    self:drawRoom()
    self:drawMachine(ui)
    self:drawWall(ui,actions)
    self:drawRiver(ui)
    self:drawReceipt(ui)
    self:drawHand(ui)
    for _,flight in ipairs(self.feedback.flights) do
        local pose,t=Feedback.pose(flight)
        self:drawFlat(flight.tile,pose,flight.flip and t<.45,flight.fade and (1-t) or 1)
    end
    if self.drag then
        local drag=self.drag
        self:surface(heldPose(drag.x,drag.y),nil,self.art.faces[drag.tile.kind])
    end
    self:drawControls(ui,actions)
    if self.feedback.stampTime>0 then
        self:text("本次 +"..self.feedback.stamp,460,233,32,C.gold,360,"center")
    end
    love.graphics.setColor(1,1,1,.7); love.graphics.draw(self.art.vignette)
    self:drawOverlays(ui,actions)
    if ui.logError then self:text("试玩日志写入失败",950,798,14,C.gold) end
end

function Table:onAction(method,before,run,index)
    self.detail,self.archive=false,false
    if method=="draw" then
        local tile=run.hand[15]
        local count=#run.wall+1
        local source=self:wallTilePose(math.ceil(count/2),count%2==0 and 2 or 1)
        self.feedback:spawn(tile,source,self:handPose(15),.30,false,true)
        self.feedback:play("tile")
    elseif method=="discard" then
        local tile=before[index]
        local from=self.poses[tile.id] or self:handPose(index)
        if self.drag then
            local x,y=self.drag.x,self.drag.y
            from=heldPose(x,y)
        end
        self.feedback:spawn(tile,from,self:riverPose(#run.discards,#run.discards),.24)
    elseif method=="settle" then
        self.feedback:play("button"); self.feedback:play("score")
        for i,tile in ipairs(before) do
            self.feedback:spawn(tile,self.poses[tile.id] or self:handPose(i),
                self:flat((i-7.5)*26,510,30,46,12),.30+i*.012,true)
        end
        for i,tile in ipairs(run.hand) do
            local count=#run.wall+#run.hand-i+1
            local source=self:wallTilePose(math.ceil(count/2),count%2==0 and 2 or 1)
            self.feedback:spawn(tile,source,self:handPose(i),.32+i*.012,false,true)
        end
        self.feedback.target,self.feedback.stamp,self.feedback.stampTime=run.total,run.lastResult.total,1.1
    end
    self.drag=nil
end

function Table:press(ui,x,y)
    if self.detail or self.archive then return false end
    for i=#ui.tileRects,1,-1 do
        local rect=ui.tileRects[i]
        if Table.hit(rect,x,y) then
            ui.hoverIndex,ui.hoverId=rect.index,rect.tileId
            if ui.run.phase=="discard" then
                self.drag={index=rect.index,id=rect.tileId,tile=ui.run.hand[rect.index],
                    startX=x,startY=y,x=x,y=y,moved=false}
                for j=#self.feedback.flights,1,-1 do
                    if self.feedback.flights[j].tile.id==rect.tileId then table.remove(self.feedback.flights,j) end
                end
            end
            return true
        end
    end
    return false
end

function Table:move(x,y)
    if not self.drag then return end
    local drag=self.drag
    drag.x,drag.y=x,y
    if (x-drag.startX)^2+(y-drag.startY)^2>64 then drag.moved=true end
end

function Table:release(ui,x,y,discard)
    local drag=self.drag
    if not drag then return end
    if not drag.moved or Table.hit(self.dropRect,x,y) then
        discard(drag.index)
    else
        local to=self:handPose(drag.index)
        self.feedback:spawn(drag.tile,heldPose(x,y),to,.18)
        self.drag=nil
    end
end

function Table:escape()
    if self.drag then self.drag=nil; return true end
    if self.detail or self.archive then self.detail,self.archive=false,false; return true end
    return false
end

function Table:update(dt,mx,my)
    self.feedback:update(dt)
    local targetX,targetY=0,0
    if not self.feedback.reduced then targetX,targetY=(mx-640)/640*2,(my-420)/420*1.5 end
    local ease=math.min(1,dt*8)
    self.offsetX,self.offsetY=self.offsetX+(targetX-self.offsetX)*ease,self.offsetY+(targetY-self.offsetY)*ease
    if self.feedback.reduced then self.offsetX,self.offsetY=0,0 end
end

return Table
