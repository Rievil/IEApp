obj=MyDAQ('ss');
%%
obj.start;

%%
as=Asker();
as.StartReading;


%%
delete(as);

