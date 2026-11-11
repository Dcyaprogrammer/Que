function love.conf(t)
    t.version = "11.5"
    t.identity = "que-core-loop"
    t.window.title = "Que · 麻将构筑原型"
    t.window.width, t.window.height = 1280, 840
    t.window.resizable = true
    t.window.minwidth, t.window.minheight = 960, 630
    t.window.highdpi = true
    t.modules.physics, t.modules.joystick = false, false
    if arg and table.concat(arg, " "):find("--test", 1, true) then
        t.window = false
        t.modules.graphics = false
        t.modules.audio, t.modules.sound = false, false
    end
end

if arg then
    local args = table.concat(arg, " ")
    if args:find("--frames", 1, true) or args:find("--test", 1, true) then
        function love.errorhandler(message)
            print("ERROR: " .. tostring(message) .. debug.traceback("", 2))
            return function() return 1 end
        end
    end
end
