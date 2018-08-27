using Reel
using Test

using Gadfly

let
    function render(t, dt)
        # t is the time into the sequence
        # dt is the time to advance for the next frame

        # any expression that results in an object which can be
        # rendered as png or jpg
        plot([x -> sin(x+t*π), x -> cos(x+t*π)], 0, 6)
    end

    film = roll(render, fps=30, duration=2)

    write("output.gif", film) # Write to a gif file
    write("file.webm", film) # Write to a webm video
    write("file.mp4", film)  # An mp4 formatted video

    @show typeof((render(t,0.1) for t in 0:0.1:2))
    roll((render(t,0.1) for t in 0:0.1:2), fps=30)
    write("output2.gif", film) # Write to a gif file
end

let
    film = roll(fps=30, duration=2) do t, dt
        plot([x -> sin(x+t*π), x -> cos(x+t*π)], 0, 6)
    end

    write("output.gif", film)
end

# using Compose
# let
#     Compose.set_default_graphic_size(3inch, 3inch) # Square

#     # draw a regular n-gon
#     ngon(n) = compose(context(units=UnitBox(-1, -1, 2, 2)), fill("lightblue"),
#                        polygon([(cos(x), sin(x)) for x in π/2:2π/n:3.5π]))

#     roll(map(ngon, [3:10, 9:-1:3])), fps=5)

#     write("output.gif", film)
# end

let
    frames = Frames(MIME("image/png"), fps=2)

    for i=1:31
        t = i * 0.1
        push!(frames, plot([x -> sin(x+t*π), x -> cos(x+t*π)], 0, 6))
    end

    write("output.gif", frames)
    # write("output.webm", frames)
end

# issue 16  https://github.com/shashi/Reel.jl/issues/16
let
    ts = []
    film = roll(fps=1, duration=5) do t, dt
        push!(ts, t)
        plot([x -> sin(x+t*π), x -> cos(x+t*π)], 0, 6)
    end
    @test all(diff(ts).==1.0)
end
