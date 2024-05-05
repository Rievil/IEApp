%https://mksqlite.sourceforge.net/de/da3/detail_desc.html
%Create or open database
mksqlite('open', 'my_test.db');
list=struct2table(mksqlite('show tables'));
list.("tablename")=string(list.("tablename"));
%%
mksqlite('close');
%%

mksqlite('open','App\signal_storage.db3');
% Creating tables

%signal table
sqlstr=['CREATE TABLE signal_table2 (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,',...
                                    'signal BLOB, sampling_rate INT, period NUMERIC, channels INT,', ...
                                    'time_start NUMERIC, time_end NUMERIC, samples INT, duration NUMERIC,',...
                                    'trigger_value NUMERIC, pre_trigger_time NUMERIC, trigger_type INT,',...
                                    'datetime TEXT)'];

mksqlite(sqlstr);
mksqlite('Begin');
mksqlite('Commit');
mksqlite('close');
%% Get last id
mksqlite( 'open', 'my_test.db');
% sqlstr="SELECT seq FROM sqlite_sequence WHERE name=""signal_table""";
% sqlstr="SELECT last_insert_rowid()";
% mksqlite('DELETE FROM signal_table WHERE id>0;')

%Getting last ID from table
id=mksqlite('select seq from sqlite_sequence where name="signal_table"');


% query = mksqlite( 'SELECT * FROM signal_table' );

%Filtering by datetime
query = mksqlite( 'SELECT * FROM signal_table WHERE datetime>"26.03.2024 18:33:00"');

mksqlite('close');