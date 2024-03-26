function DrawResult(signal,fs,ax)
    data=struct;
    data.signal=signal;
    data.fs=fs;

    [fx,fy]=MyPower(signal,fs,20);
    cla(ax);
    plot(ax,fx,fy);
    xlim([200,20000]);
    set(ax,'YScale','log');
    %DrawCWT(ax,GetFCWT(data));   
end
