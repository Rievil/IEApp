function result=GetFCWT(data)
    signal=data.signal;
    fs=data.fs;
    
    flim=[200,20000];
    % startf=10;
    % endf=80e+3;
    startf=flim(1);
    endf=flim(2);
    samples=numel(signal);
    period=1/fs;
    x=linspace(0,period*samples,samples)';
    
    signal = single(signal.');
    
    % plot(time,sginal);
    tic;
    [B,fcwty] = fCWT(signal,1,fs,startf,endf,400,1);
    fcwt_tfm_sig = abs(B.');
    
    
    result=struct;
    result.imf=fcwt_tfm_sig;
    result.x=x;
    result.fcwty=fcwty;
end