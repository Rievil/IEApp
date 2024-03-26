
rng("default");

signal=rand(100000,1);

fs=44000;
period=1/fs;
samples=numel(signal);
duration=samples*period;
time=linspace(0,duration,samples)'-0.05;

sig=struct;
sig.ID=1;
sig.Data=signal;
sig.SamplingFrequency=fs;
sig.Period=period;
sig.Duration=duration;
sig.Time=[time(1),time(end)];
sig.Samples=samples;
sig.Time=datetime('now','format','dd.MM.yyyy HH:mm:ss.ss');


sig2=sig;
sig2.ID=2;

sigs=[sig,sig2];

%%

dbfile = fullfile(pwd,"App\mysqlite.db"); 
conn = sqlite(dbfile,"create");
%%
y = typecast(sig.Data, 'int32').';
%%
yi=format(y,'hex');
%%
yii=getByteStreamFromArray(sig.Data);
% y = typecast(struct, 'int32').';

%%
dbfile = fullfile(pwd,"App\mysqlite.db");
conn = sqlite(dbfile);
%%
sqlquery = strcat("CREATE TABLE Signals(ID PRIMARY_KEY INT, ", ...
    "Signal BLOB)");

execute(conn,sqlquery);
%%
dbfile = fullfile(pwd,"App\mysqlite.db");
conn = sqlite(dbfile);


results = table(sig.ID,{sig},'VariableNames',["ID","Signal"]); 

tablename = "Signals"; 
sqlwrite(conn,tablename,results); 
%%
mksqlite( 'typedBLOBs', 1 );



