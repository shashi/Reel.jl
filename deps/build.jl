if is_linux()
    if !success(`which ffmpeg`)
        run(`sudo apt-get install ffmpeg`)
    end
    if !success(`which convert`) && !success(`which magick`)
        run(`sudo apt-get install imagemagick`)
    end
elseif is_apple()
    if !success(`which ffmpeg`)
        run(`brew install ffmpeg`)
    end
    if !success(`which convert`) && !success(`which magick`)
        run(`brew install imagemagick`)
    end
elseif is_windows()
    warn("You will need to manually ensure that ffmpeg and imagemagick are installed on Windows")
end