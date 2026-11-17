-- Echo-ring splash for KDash-compatible display objects, in normalized coordinates.
local M = {}
function M.draw(display)
    local w,h=display.width,display.height
    local cx,cy=w/2,h/2
    local radius=math.min(w,h)*0.145
    display:begin_frame(true)
    display:circle(cx,cy,radius,'ink',false,8)
    -- Mirrored inner echo marks, matching the selected SVG identity.
    for _,sign in ipairs({-1,1}) do
        local px,py
        for i=0,32 do
            local y=-0.58+1.16*i/32
            local x=sign*(0.27+0.22*math.sqrt(math.max(0,1-(y/0.83)^2)))
            local nx,ny=cx+x*radius,cy+y*radius
            if px then display:line(px,py,nx,ny,'ink',7) end
            px,py=nx,ny
        end
    end
    display:circle(cx,cy,radius*.16,'ink',true)
    return display:flush({full=true})
end
return M
