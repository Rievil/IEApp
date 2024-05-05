clear all;
close all;
%% Connecting to db

% [file,location] = uigetfile('*.db','Select folder for saving .db file');

% file = "C:\Users\Richard\OneDrive - Vysoké učení technické v Brně\Měření\my_test.db";
% 
% cur=cd;
% cd(location);
% db_name=sprintf("%s%s",location,file);
mksqlite( 'open', 'my_test2.db');
% cd(cur);


%% Creating tables

%signal table

mksqlite('Begin');
sql_signal=['CREATE TABLE signal_table (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,',...
                                    'signal BLOB, sampling_rate INT, period NUMERIC, channels INT,', ...
                                    'time_start NUMERIC, time_end NUMERIC, samples INT, duration NUMERIC,',...
                                    'trigger_value NUMERIC, pre_trigger_time NUMERIC, trigger_type INT,sub_id INT,',...
                                    'source_id INT, datetime TEXT)'];

sql_asset=['CREATE TABLE asset (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT,',...
           'data BLOB)'];

sql_desc=['CREATE TABLE desc (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,',...
                             'sig_id INT,',...
                             'FOREIGN KEY(sig_id) REFERENCES signal_table(id))'];

sql_source=['CREATE TABLE source_devices (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,',...
                                    'driver_name TEXT, driver_version TEXT,',...
                                    'device_name TEXT, datetime TEXT)'];



mksqlite(sql_signal);
mksqlite(sql_asset);
% mksqlite(sql_desc);
mksqlite(sql_source);


% mksqlite('Commit');
%%
T=table(1,false,"A",40,0.25,'VariableNames',["Number","State","Mixture","Noms","Rate"]);
names=string(T.Properties.VariableNames);

sql_desc=['CREATE TABLE desc (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ',...
                             'sig_id INT,'];

for name=names
    arr=T.(name);
    var_name=class(arr);
    switch var_name
        case 'double'
            line=sprintf('%s NUMERIC,',name);
        case 'logical'
            line=sprintf('%s BOOL,',name);
        case 'string'
            line=sprintf('%s TEXT,',name);
        otherwise
            disp(class(arr));
    end
    sql_desc=sprintf('%s %s\n',sql_desc,line);
end
sql_desc=sprintf('%s FOREIGN KEY(sig_id) REFERENCES signal_table(id))',sql_desc);
disp(sql_desc);
mksqlite(sql_desc);
mksqlite('Commit');
%% Create description table



%%
as.SignalsTable
%% How to decide with which id should we insert?
id=mksqlite('select seq from sqlite_sequence where name="signal_table"');
if isempty(id)
    disp('first id will be 1')
else
    fprintf("next id will be %d\n",id.seq+1);
end
%% Adding signals to signal table


sqlstr=['INSERT INTO signal_table (signal, sampling_rate, period, channels,', ...
                                    'time_start, time_end, samples, duration,',...
                                    'trigger_value, pre_trigger_time, trigger_type,',...
                                    'datetime) VALUES ',...
                                    '(?,?,?,?,?,?,?,?,?,?,?,?)'];

signal=struct;
signal.Mic=sin(linspace(0,8*pi(),20000));

rate=120;
samples=numel(signal.Mic);
period=1/120;
duration=samples*period;
channels=1;
pretrigger_time=-0.05;
time=linspace(0,duration,samples)'+pretrigger_time;
start_time=time(1);
end_time=time(end);
trigger_type=1;
trigger_value=0.05;
date_time=char(datetime('now','format','dd.MM.yyyy HH:mm:ss.ss'));



mksqlite( 'param_wrapping', 0 );
mksqlite( 'typedBLOBs', 2 );
% mksqlite('INSERT INTO signal_table (signal,period,datetime) VALUES (?,?,?)',signal,period,date_time);
mksqlite(sqlstr,signal,rate,period,channels,start_time,end_time,samples,duration,...
    trigger_value,pretrigger_time,trigger_type,date_time);

id=mksqlite('select seq from sqlite_sequence where name="signal_table"');

%% Inserting to the table blob data

mksqlite( 'typedBLOBs', 2 );

sig=struct;
% sig.ID=1;
sig.Double=table(sin(linspace(0,8*pi(),20000)),'VariableNames',{'Arr'});
sig.SamplingFrequency=120;
sig.Period=0.001;
sig.Duration=2;
sig.Time=[-0.05,0.5];
sig.Samples=35;
sig.Time=datetime('now','format','dd.MM.yyyy HH:mm:ss.ss');

mksqlite( 'INSERT INTO big_test_table (signals) VALUES (?)', sig );

%% Retriving data
query = mksqlite( 'SELECT * FROM signal_table' );
%% Get list of tables in db
tables=mksqlite('show tables');
names=string({tables.tablename});


%% Closing connection
mksqlite('close');
%%

