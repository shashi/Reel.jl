__precompile__(true)

module Reel

import Base: write, push!, show
export Frames, roll

global _output_type = "webm"
function set_output_type(t)
    global _output_type
    _output_type = t
end

mutable struct Frames{M <: MIME}
    tmpdir::String
    length::UInt
    fps::Float64
    rendered::Union{Void, String}
    function Frames{M}(; fps=30) where {M <: MIME}
        tmpdir = mktempdir()
        obj = new(tmpdir, 0, fps, nothing)
        finalizer(obj, x -> rm(x.tmpdir, force=true, recursive=true))
        obj
    end
end
Frames{M <: MIME}(m::M; fps=30) = Frames{M}(fps=fps)

extension(m::MIME"image/png") = "png"
extension(m::MIME"image/jpeg") = "jpg"
extension(s::String) = split(s, ".")[end]

function writeframe(filename, mime::MIME, frame)
    file = open(filename, "w")
    show(file, mime, frame)
    close(file)
end


function push!{M}(frames::Frames{M}, x)
    frames.length += 1
    writeframe(
        joinpath(frames.tmpdir,
            string(frames.length, ".", extension(M()))),
        M(), x)
    frames
end

const mime_ordering = map(MIME, [
    "image/png",
    "image/svg",
    "image/jpeg",
    "text/html"
])

function bestmime(x)
    for m in mime_ordering
        if mimewritable(m, x)
            return m
        end
    end
end

function write{M}(f::String, frames::Frames{M}; fps=frames.fps)
    # TODO: more ffmpeg options
    dir = frames.tmpdir
    ext = extension(M())
    oext = extension(f)

    if oext == "gif"
        # The maximum delay widely supported by clients is 2 ticks (100 ticks per sec)
        #delay = max(round(100/fps), 2) |> int
        args = reduce(vcat, [[joinpath("$dir", "$i.$ext"), "-delay", "1x$fps", "-alpha", "deactivate"] for i in 1:frames.length])
        cmd = try readstring(is_unix() ? `which convert` : `where convert`)
        catch e1
            try readstring(is_unix() ? `which magick` : `where magick`)
            catch e2
                error("Could not find imagemagick binary. Is it installed?")
            end
        end |> strip
        imagemagick_cmd = `$cmd $args $f`
        #run(`convert -alpha remove $dir/*.$ext -delay $delay $f`)
        run(imagemagick_cmd)
        frames.rendered = f
    else
        # note that ffmpeg's option is positional-dependend
        global_opts = [
            "-y",
            "-r", fps,
        ]
        input_opts = [
            "-i", "$dir/%d.$ext"  # this should be the finial one of input options
        ]
        output_opts = [
            "-pix_fmt", :yuv420p,  # make the output file work on firefox
            f  # output path
        ]
        run(pipeline(`ffmpeg $global_opts $input_opts $output_opts`,
                     stdout=DevNull, stderr=DevNull))
        frames.rendered = f
    end
end


### Roll teh camraz! ###

function roll(render::Union{Function, Type};
                 fps=30, duration=5.0)
    t      = 0.0
    dt     = 1.0 / fps
    steps  = duration / dt
    frame  = render(t, dt)
    mime   = bestmime(frame)
    frames = Frames(mime, fps=fps)
    push!(frames, frame)

    for i=2:steps
        t += dt
        push!(frames, render(t, dt))
    end
    frames
end

function roll(frames::Union{AbstractArray, Base.Generator}; fps=30)
    @assert length(frames) > 1
    mime = bestmime(first(frames))
    reduce(push!, Frames(mime, fps=fps), frames)
end

function newname!(ext)
    string("reel-", rand(UInt), ".", ext)
end

#### writemimes - now Base.show ####
# TODO: research the crap out of this

function writehtml(io::IO, file, file_type::AbstractString)
    randstr = rand(UInt)
    if file_type == "gif"
        write(io, """<img src="$file?$randstr" />""")
    elseif file_type == "webm"
        write(io, """<video autoplay controls><source src="$file?$randstr" type="video/webm"></video>""")
    elseif file_type == "mp4"
        write(io, """<video autoplay controls><source src="$file?$randstr" type="video/mp4"></video>""")
    end
end

function show(io::IO, ::MIME"text/html", frames::Frames)
    # If IJulia is present, see if the frames are rendered
    global _output_type
    if frames.rendered == nothing || !isfile(frames.rendered) || extension(frames.rendered) != _output_type
        fn = newname!(_output_type)
        write(fn, frames)
        frames.rendered = fn
    end

    if isdefined(Main, :IJulia)
        if frames.rendered != nothing
            if startswith(abspath(frames.rendered), abspath(""))
                # we can serve it right up from here.
                file = replace(abspath(frames.rendered), abspath(""), "")
                writehtml(io, "files/" * file, extension(file))
            else
                # the file is unreachable to the server, so we symlink or copy it.
                fn = newname!(_output_type)
                try
                    symlink(frames.rendered, fn)
                catch
                    cp(frames.rendered, fn)
                end
                writehtml(io, "files/" * fn, extension(fn))
            end
        end
    else
        # TODO base64 encode, so many possible types!
        # write(io, """<video autoplay controls><source src="files/$(frames.rendered)" type="video/webm"></video>""")
    end
end

function cleanup()
    run(`rm reel-'*'.'*'`)
end


end # module
