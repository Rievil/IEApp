clear all;
close all;
%% Connecting to db

% [file,location] = uigetfile('*.db','Select folder for saving .db file');

% file = "C:\Users\Richard\OneDrive - Vysoké učení technické v Brně\Měření\my_test.db";
% 
% cur=cd;
% cd(location);
% db_name=sprintf("%s%s",location,file);
mksqlite( 'open', 'my_test.db');
% cd(cur);


%% Creating tables

%signal table
sqlstr=['CREATE TABLE signal_table (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,',...
                                    'signal BLOB, sampling_rate INT, period NUMERIC, channels INT,', ...
                                    'time_start NUMERIC, time_end NUMERIC, samples INT, duration NUMERIC,',...
                                    'trigger_value NUMERIC, pre_trigger_time NUMERIC, trigger_type INT,',...
                                    'datetime TEXT)'];

mksqlite(sqlstr);
mksqlite('Begin');
mksqlite('Commit');
%%
as.SignalsTable
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
%% Closing connection
mksqlite('close');