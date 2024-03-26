function DrawCWT(ax,result)
    cla(ax);
    flim=[200,20000];
    
    image(result.imf,"CDataMapping","scaled","XData",result.x,"YData",result.fcwty,'parent',ax);
    set(ax,'YDir','normal','YScale','log','TickDir','out');
    colormap(jet);
    xlim(ax,[-0.03,0.08]);
    
    ylim(ax,flim);
    xlim(ax,flim);
end