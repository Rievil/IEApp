files=struct2table(dir(cd));
files.("name")=string(files.("name"));
files=files(contains(files.name,".csv"),:);
%%
file=files.name(4);


T=readtable(file);
freq=60e+3;
period=1/freq;
samples=size(T,1);
time=linspace(0,samples*period,samples)';

T=table(time,T.Var1,'VariableNames',["Time","Amp"]);
T=T(T.Time<0.6,:);
% T.Amp=T.Amp-mean(T.Amp); 4.9359e+04
T.Amp=T.Amp-4.9359e+04;

[f,y]=MyPower(T.Amp,freq);
subplot(1,2,1);
han=plot(T.Time,T.Amp);

subplot(1,2,2);
plot(f,y);
set(gca,'YScale','log');
%%
idx=logical(get(han,'brushData'));
val=mean(T.Amp(idx));
%%
t=seconds(T.Time);
TT=timetable(T.Amp,'RowTimes',t);%%

%%
obj=AnalogTriggerApp;
%%

plot(T.Signal{4}.Time,T.Signal{4}.Amp)

%%

vars=who;

T=table;
for i=1:numel(vars)
    T=[T;table(string(vars(i)),{eval(vars{i})},'VariableNames',["name","Signal"])];
end
%%
save("Signals_2.mat","T");